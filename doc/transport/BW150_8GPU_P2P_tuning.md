# BW150 单机 8 卡 P2P 调优指南

> 适用环境：海光 BW150（gfx936）×8，4-socket 单机，RCCL 2.22.3-HEAD，HIP 6.3.3，ROCm 6.3.3
> 实测：默认 BIOS 配置 8 卡 allreduce busbw 仅 **5.1 GB/s**；按本文 §0 BIOS + §1 环境变量调优后达到 **61 GB/s**（约 12×，接近 PCIe Gen5 x16 上限）

---

## 0. 关键前置：BIOS 配置（决定性提升，单机必改）

> 以下配置在海光 EDKII BIOS 下生效。**这一节改完，从 5 GB/s 跳到 60+ GB/s**——比 RCCL 层面的所有调优加起来都大。

| 配置路径 | 值 | 作用 | 影响档 |
| --- | --- | --- | --- |
| `Socket Configuration → IIO Configuration → Pcie Relaxed ordering` | **Enabled** | 开启 PCIe 写完成乱序，提升 P2P DMA 吞吐 | ⭐⭐⭐ |
| `Socket Configuration → Uncore Configuration → Uncore General Configuration → PCIE Remote P2P relaxed Ordering` | **Enabled** | **跨 socket 的 PCIe P2P 乱序优化**——4-socket 拓扑下打通 P2P 的关键 | ⭐⭐⭐⭐⭐ |
| `Advanced → PCI Subsystem Settings → Re-Size Bar Support` | **Enabled** | Resizable BAR，CPU 一次性看到 GPU 全 BAR 空间（不再 256MB 分段），DMA 效率倍增 | ⭐⭐⭐⭐ |
| `Socket Configuration → Memory Configuration → Page policy → page policy` | **Closed** | 内存 page close 策略，小/中等工作集延迟更友好 | ⭐⭐ |
| `Socket Configuration → Advanced PM Configuration → CPU-Advanced PM Tuning → Latency optimize Mode` | **Enable** | 延迟优化模式 | ⭐⭐ |
| `Socket Configuration → Advanced PM Configuration → CPU-Advanced PM Tuning → Energy Perf BIAS → Power Performance Tuning` | **BIOS Controls EPB (0x1)** | CPU 偏 performance 档 | ⭐ |
| `Socket Configuration → Advanced PM Configuration → CPU-Advanced PM Tuning → Energy Perf BIAS → ENERGY_PERF_BIAS_CFG mode` | **Performance (0x0)** | 强制 performance | ⭐ |
| `Socket Configuration → Advanced PM Configuration → CPU C State Control → Monitor MWAIT` | **Enabled** | 监控 MWAIT，避免乱进 C-state | ⭐ |
| `Socket Configuration → Advanced PM Configuration → CPU C State Control → ACPI C6x Enumeration` | **Auto**（期望 enabled） | C6x 状态控制 | ⭐ |

**Linux 下补一刀**：

```bash
# CPU governor 锁 performance（必须）
sudo cpupower frequency-set -g performance
# 校验
cpupower frequency-info | grep "current policy"
```

### 0.1 关于"是否要改 NPS"

之前我（基于拓扑观察）倾向于把 NPS 从 4 改成 1 来合并 NUMA 域，但实测证明**不需要**——4-socket 拓扑下只要把 **PCIE Remote P2P Relaxed Ordering 打开**，跨 socket P2P 就能跑满。这意味着：

- **保留 NPS=4 反而更好**：NUMA 亲和绑核更精确，每个 rank 能绑到本地 socket
- **不要轻易动 NPS**：改了之后 lspci / numactl 看到的拓扑全变，下游运维脚本可能都要调整

---

## 0.2 拓扑速览（来自 `hy-smi-showbus.log`）

| Rank | BDF    | Socket |
| ---- | ------ | ------ |
| 0    | 2f:00  | 3      |
| 1    | 32:00  | 2      |
| 2    | 40:00  | 1      |
| 3    | 43:00  | 0      |
| 4    | 9a:00  | 3      |
| 5    | 9d:00  | 2      |
| 6    | cd:00  | 1      |
| 7    | d0:00  | 0      |

**结论**：每个 PCIe hop 都跨 socket，必然走 UPI/Infinity Fabric。优化目标就是：**缩短跨 socket 路径 + 减少 PCIe 翻译开销**。

---

## 0.3 根因复盘

之前看到 4-socket 拓扑 + Ring 跨 socket 通信，倾向于把根因归到"NPS 必须是 1"或"必须改 RCCL ring 构造"。**实测推翻了这个判断**：

- **真正的瓶颈是 BIOS 默认配置禁用了 PCIe P2P 关键优化**（特别是 Remote P2P Relaxed Ordering 和 Resizable BAR）
- 在海光 EDKII 默认 BIOS 下，跨 socket P2P 走的路径虽然硬件能通，但软件层没有启用 DMA 乱序，**单次传输的有效带宽被 PCIe 完成顺序（Completion Order）规则严重约束**
- 把 Remote P2P RO 打开后，4-socket 拓扑不再是个问题，PCIe 链路能跑满 ~63 GB/s

**教训**：看 `lspci -vvv` 输出的 `MaxPayload` / `MaxReadReq` / `Relaxed Ordering` 是否被禁，比猜 NPS 更直接。

---

## 1. 立即生效（不需重启）

### 1.1 环境变量（写进 `~/.bashrc` 或测试脚本头部）

```bash
# ==== ROCm / HSA ====
export HSA_FORCE_FINE_GRAIN_PCIE=1          # 必须：避免 bounce buffer，带宽/延迟立竿见影
export HSA_AMD_PCM_PEAK_MODE=1              # 可选：监控频率

# ==== RCCL 调优 ====
export NCCL_DEBUG=INFO                      # 调优时打开；生产环境关掉
export NCCL_DEBUG_SUBSYS=ALL                # 调优时打开
export NCCL_IB_DISABLE=1                    # 没 IB 设备，写明确避免探测
export NCCL_NET_DISABLE=0                   # 允许走 NET（虽然这里只有 socket）

# 算法与协议（单机 PCIe 默认 ring 不优，强制 tree 对 8 卡 allreduce 更友好）
export NCCL_ALGO=tree                       # 8 卡场景 tree 通常优于 ring
export NCCL_PROTO=simple                    # PCIe P2P 用 simple 即可（LL/LL128 是 IB 优化）
# 大包时切回 ring（>256MB）
# export NCCL_ALGO=ring

# P2P chunksize：默认 256KB 偏小，单机 PCIe 可放大
export NCCL_P2P_CHUNKSIZE=524288            # 512KB；大包场景可试 1MB

# ==== 系统提示抑制（业务可选） ====
export NCCL_IGNORE_CPU_AFFINITY=0           # 不要关，让 RCCL 自动绑核
```

### 1.2 sysctl（runtime 即时生效，重启后失效）

```bash
# 关闭 NUMA balancing：避免进程运行时页迁移
sudo sysctl -w kernel.numa_balancing=0

# 关闭 transparent hugepage 干扰（按需）
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled

# 校验
cat /proc/sys/kernel/numa_balancing         # 应为 0
```

如需永久写入 `/etc/sysctl.d/99-rccl.conf`：

```bash
sudo tee /etc/sysctl.d/99-rccl.conf <<EOF
kernel.numa_balancing=0
vm.zone_reclaim_mode=0
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
EOF
sudo sysctl -p /etc/sysctl.d/99-rccl.conf
```

---

## 2. 需重启（一次性配置）

### 2.1 内核 cmdline 加 `iommu=pt`（Pass-Through，关闭 IOMMU 翻译）

```bash
# 查看当前 cmdline
cat /proc/cmdline

# 编辑 grub（以 grub2 为例）
sudo sed -i 's/^\(GRUB_CMDLINE_LINUX=".*\)"$/\1 iommu=pt amd_iommu=on"/' /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```

验证：

```bash
cat /proc/cmdline | grep -o 'iommu=pt'
dmesg | grep -i iommu | head -5
```

### 2.2 中断亲和与 NUMA 绑核（重启后由 RCCL 自动处理）

如果想要确定性最强、避免 OS 调度干扰，可用 `numactl` 显式绑：

```bash
# 装 numactl
sudo yum install -y numactl
```

---

## 3. 测试与验证流程

### 3.1 单次跑分（手动调整参数对比）

```bash
#!/bin/bash
# save as run_allreduce.sh
set -e

# 1. baseline 环境变量（按 §1.1 设置）
export HSA_FORCE_FINE_GRAIN_PCIE=1
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=ALL
export NCCL_IB_DISABLE=1
export NCCL_ALGO=tree
export NCCL_PROTO=simple
export NCCL_P2P_CHUNKSIZE=524288

# 2. sysctl（runtime）
sudo sysctl -w kernel.numa_balancing=0

# 3. 跑 allreduce，1MB~1GB
mpirun --allow-run-as-root -np 8 \
  -H localhost:8 \
  -bind-to none -map-by slot \
  /opt/dtk/bin/all_reduce_perf \
    -b 1M -e 1G -f 2 -g 1 \
    -c 0 -n 20 -w 5 \
    -o /tmp/rccl_out.log
```

### 3.2 关键指标

观察 `rccl_out.log` 末尾：

```
# Avg bus bandwidth    : ???        ← 目标 ≥ 60 GB/s（已验证可达 61 GB/s）
# Out of bounds values : 0 OK
```

同时观察 `debug.log` 中：

```
NCCL INFO Trees [...]                    ← 算法是否切到 tree
NCCL INFO Channel 00/30 : ...            ← ring 顺序（应被 algo=tree 覆盖）
NCCL INFO 30 coll channels ... 32 p2p channels
```

### 3.3 分组对照实验

| 轮次 | 改动                                                       | 实测 busbw  |
| ---- | ---------------------------------------------------------- | ----------- |
| A0   | 仅默认配置（BIOS 默认 + 无环境变量）                       | 5.1 GB/s    |
| **B0** | **+ §0 BIOS 全部开关（Remote P2P RO / Re-Size BAR / Closed page）** | **~55~60 GB/s** |
| B1   | + `HSA_FORCE_FINE_GRAIN_PCIE=1`                            | +5~10%      |
| B2   | + `kernel.numa_balancing=0`                                | 略升        |
| B3   | + `NCCL_ALGO=tree NCCL_PROTO=simple`                       | 持平或微升  |
| B4   | + `NCCL_P2P_CHUNKSIZE=524288`                              | 小包场景 +  |
| B5   | + `iommu=pt`（重启后）                                     | +5~10%      |
| B6   | + numactl 绑核到对应 socket                                | 稳定性+    |
| B7   | + cpupower -g performance                                  | 一致性      |

> **实测终点**：以上全部做完约 **61 GB/s**（已贴近 PCIe Gen5 x16 的 allreduce 上限）。
> 超过这个量级需要改 RCCL 源码（socket-aware ring / NVLS 替代方案）。

> 注：A0 → B0 这一个跃迁比后续所有优化加起来都大，**§0 BIOS 必须先做**。

---

## 4. 进阶：消除跨 socket 路径（源码级）

当上面 A0~A6 都做完，离上限还有 2~3× 空间时，瓶颈就在 **RCCL 构造 ring 时把同 socket 的卡也串到跨 socket 路径上**。

### 4.1 改造方向

在 `RCCL_TOPO` 阶段，按 NUMA 节点对 rank 分组，**先在同 socket 内做局部 ring/halving，再跨 socket 做全局归约**。类似 NV 的 NVLink-aware topology 思路。

### 4.2 关键源码入口

```
src/collectives.cc              # 算法调度
src/graph/paths.cc              # ring/tree 构造
src/graph/topo.cc               # 拓扑探测（NUMA 节点获取）
src/transport/p2p/              # P2P transport
```

参考已公开 patch：
- RCCL 社区有 `RCCL_SOCKET_AWARE_RING` 类似提案，可作为起点。
- 上下游：先看 `ncclTopoGetSystem()` 返回的 NUMA 节点信息，再改 `ncclGetRoute()` / `ncclTreeBase()`。

> 这部分**需要重建 RCCL**（`hipify` + `make`），且验证周期长。建议先把 §1~§3 的 2~3× 拿到，再决定是否值得动源码。

---

## 5. 验证清单（贴板用）

```
== BIOS（必做，一次性）==
[ ] Pcie Relaxed ordering           = Enabled
[ ] PCIE Remote P2P relaxed Ordering = Enabled    ← 最关键
[ ] Re-Size Bar Support             = Enabled
[ ] Page policy                     = Closed
[ ] Latency optimize Mode           = Enable
[ ] Energy Perf BIAS / MWAIT / C6x  = Performance / Enabled / Auto
[ ] cpupower -g performance         已设

== 系统 / 内核（必做）==
[ ] HSA_FORCE_FINE_GRAIN_PCIE=1  已加
[ ] kernel.numa_balancing=0      已设
[ ] iommu=pt                     已加进 cmdline（需重启）

== RCCL 调优（必做）==
[ ] NCCL_IB_DISABLE=1            已加
[ ] NCCL_ALGO=tree / NCCL_PROTO=simple  试过
[ ] NCCL_P2P_CHUNKSIZE=524288    试过

== 验收 ==
[ ] busbw ≥ 60 GB/s              已达（参考线：8 卡 PCIe Gen5 ≈ 55~63 GB/s）
[ ] numactl 绑核                可选
[ ] 跨 socket 通信比例            是否有 profile 工具能统计（perftest 加 PROFILE=1）
```

---

## 附录 A：常见误区

| 误区                                                | 正确做法                                                     |
| --------------------------------------------------- | ------------------------------------------------------------ |
| 加 `NCCL_IB_HCA` / `NCCL_IB_GID_INDEX`             | 没 IB 卡，写了也无效，反而拖慢 init                          |
| `NCCL_P2P_LEVEL=SYS` / `LOC`                       | 默认就 OK，除非想强制走某层                                  |
| `NCCL_SOCKET_NTHREADS` 调到很大                    | 默认值在小规模下已够，过大反而争抢 cache                     |
| `RCCL_ENABLE_GDRDMA=1`                             | **本场景（单机 P2P）不开**；GDRDMA 面向跨机 GPU Direct RDMA |

## 附录 B：进一步排障命令

```bash
# 1. PCIe 拓扑
lspci -tv
lspci -s <BDF> -vvv | grep -E "Speed|Width"

# 2. NUMA 拓扑
numactl -H
lscpu | grep -i numa

# 3. 跨 socket 带宽（一次性探针）
# ib_send_bw / rocm-bandwidth-test（看 P2P 路径）
/opt/rocm/bin/rocm-bandwidth-test -d 0 1

# 4. RCCL 详细 init 日志
NCCL_DEBUG=INFO NCCL_DEBUG_SUBSYS=ALL ./all_reduce_perf ...
```
