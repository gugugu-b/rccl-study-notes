# NET/IB/0/GDRDMA vs NET/IB/0 传输路径对比

> 源码位置：NCCL/RCCL `netRecvSetup` / `netSendSetup`，`ncclTopoCheckGdr`
> 场景：跨机 IB 通信，日志中 `NET/IB/0/GDRDMA` 降级为 `NET/IB/0`

<div align="center">

<style><!--
* { box-sizing: border-box; margin: 0; padding: 0; }
  :root {
    --surface: #ffffff; --surface-muted: #f6f6fb; --surface-soft: #eef0f7;
    --border: #e2e2ec; --text: #1a1a2e; --text-muted: #6b6b80;
    --brand: #7c5cff; --brand-strong: #5b3fd6; --brand-soft: #efebff;
    --accent: #e85d75; --accent-soft: #fde8ec;
    --font-sans: -apple-system, "PingFang SC", "Noto Sans CJK SC", "WenQuanYi Micro Hei", sans-serif;
    --font-mono: "SF Mono", "JetBrains Mono", "Menlo", monospace;
    --radius: 8px; --radius-card: 12px; --weight-medium: 500; --weight-strong: 700;
  }
  .bw-root { font-family: var(--font-sans); color: var(--text); background: var(--surface); border:1px solid var(--border); border-radius: var(--radius-card); padding: 20px; width: 100%; max-width: 880px; }
  .bw-title { font-size: 16px; font-weight: var(--weight-strong); margin: 0 0 4px; }
  .bw-sub { font-size: 12px; color: var(--text-muted); margin: 0 0 12px; }
  .bw-grid { display: flex; gap: 20px; align-items: stretch; }
  .bw-ring { flex: 0 0 300px; }
  .bw-derive { flex: 1; display: flex; flex-direction: column; gap: 10px; }
  .bw-derive-head { font-size: 13px; font-weight: var(--weight-medium); color: var(--text-muted); letter-spacing: .04em; text-transform: uppercase; }
  .bw-step { display: flex; gap: 10px; align-items: baseline; font-size: 14px; line-height: 1.5; }
  .bw-step .n { flex: 0 0 22px; font-family: var(--font-mono); font-size: 12px; color: var(--brand-strong); font-weight: var(--weight-strong); }
  .bw-step .t { font-family: var(--font-mono); font-size: 13px; }
  .bw-step .d { font-size: 12px; color: var(--text-muted); }
  .bw-concl { margin-top: 6px; padding: 12px 14px; background: var(--brand-soft); border:1px solid var(--brand); border-radius: var(--radius); font-size: 14px; line-height: 1.5; }
  .bw-concl .k { font-family: var(--font-mono); font-weight: var(--weight-strong); color: var(--brand-strong); }
  .bw-concl .h { font-size: 12px; color: var(--text-muted); margin-top: 4px; }
  .bw-legend { display: flex; gap: 16px; font-size: 12px; color: var(--text-muted); margin-top: 12px; flex-wrap: wrap; }
  .bw-legend span b { color: var(--text); font-weight: var(--weight-medium); }
--></style>

  <div class="bw-root">
    <div class="bw-title">NET/IB/0/GDRDMA vs NET/IB/0 数据通路对比</div>
    <div class="bw-sub">NCCL/RCCL IB 传输层 · useGdr 标志决定 buffer 位置与拷贝次数</div>
    <div class="bw-grid">
      <div class="bw-ring">
        <svg viewBox="0 0 300 340" width="300" height="340" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="ah1" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="8" markerHeight="8" markerUnits="userSpaceOnUse" orient="auto">
              <path d="M1 1 L7 4 L1 7 Z" fill="#7c5cff"/>
            </marker>
            <marker id="ah2" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="8" markerHeight="8" markerUnits="userSpaceOnUse" orient="auto">
              <path d="M1 1 L7 4 L1 7 Z" fill="#e85d75"/>
            </marker>
          </defs>
          <line x1="150" y1="20" x2="150" y2="290" stroke="#e2e2ec" stroke-width="1" stroke-dasharray="3 3"/>
          <text x="75" y="22" text-anchor="middle" fill="#5b3fd6" font-weight="700" font-size="11" font-family="-apple-system, sans-serif">GDRDMA</text>
          <rect x="35" y="35" width="80" height="32" rx="6" fill="#ffffff" stroke="#7c5cff" stroke-width="2"/>
          <text x="75" y="51" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e" font-family="-apple-system, sans-serif">GPU 显存</text>
          <line x1="75" y1="67" x2="75" y2="88" stroke="#7c5cff" stroke-width="2" marker-end="url(#ah1)"/>
          <rect x="35" y="90" width="80" height="32" rx="6" fill="#ffffff" stroke="#7c5cff" stroke-width="2"/>
          <text x="75" y="106" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e" font-family="-apple-system, sans-serif">IB 网卡</text>
          <line x1="75" y1="122" x2="75" y2="143" stroke="#7c5cff" stroke-width="2" marker-end="url(#ah1)"/>
          <rect x="35" y="145" width="80" height="32" rx="6" fill="#ffffff" stroke="#7c5cff" stroke-width="2"/>
          <text x="75" y="161" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e" font-family="-apple-system, sans-serif">网络</text>
          <text x="75" y="195" text-anchor="middle" font-size="11" fill="#5b3fd6" font-weight="600" font-family="-apple-system, sans-serif">0 次拷贝</text>
          <text x="75" y="210" text-anchor="middle" font-size="10" fill="#6b6b80" font-family="-apple-system, sans-serif">IB 直读显存</text>
          <text x="225" y="22" text-anchor="middle" fill="#e85d75" font-weight="700" font-size="11" font-family="-apple-system, sans-serif">降级</text>
          <rect x="185" y="35" width="80" height="32" rx="6" fill="#ffffff" stroke="#e85d75" stroke-width="2"/>
          <text x="225" y="51" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e" font-family="-apple-system, sans-serif">GPU 显存</text>
          <line x1="225" y1="67" x2="225" y2="88" stroke="#e85d75" stroke-width="2" marker-end="url(#ah2)"/>
          <rect x="195" y="69" width="60" height="16" rx="4" fill="#fde8ec" stroke="#e85d75"/>
          <text x="225" y="77" text-anchor="middle" dominant-baseline="central" font-size="9" fill="#e85d75" font-weight="600" font-family="-apple-system, sans-serif">D→H 拷贝</text>
          <rect x="185" y="90" width="80" height="32" rx="6" fill="#fde8ec" stroke="#e85d75" stroke-width="2"/>
          <text x="225" y="106" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e" font-family="-apple-system, sans-serif">Host 内存</text>
          <line x1="225" y1="122" x2="225" y2="143" stroke="#7c5cff" stroke-width="2" marker-end="url(#ah1)"/>
          <rect x="185" y="145" width="80" height="32" rx="6" fill="#ffffff" stroke="#7c5cff" stroke-width="2"/>
          <text x="225" y="161" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e" font-family="-apple-system, sans-serif">IB 网卡</text>
          <line x1="225" y1="177" x2="225" y2="198" stroke="#7c5cff" stroke-width="2" marker-end="url(#ah1)"/>
          <rect x="185" y="200" width="80" height="32" rx="6" fill="#ffffff" stroke="#7c5cff" stroke-width="2"/>
          <text x="225" y="216" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e" font-family="-apple-system, sans-serif">网络</text>
          <text x="225" y="250" text-anchor="middle" font-size="11" fill="#e85d75" font-weight="600" font-family="-apple-system, sans-serif">2 次拷贝</text>
          <text x="225" y="265" text-anchor="middle" font-size="10" fill="#6b6b80" font-family="-apple-system, sans-serif">D→H→NIC→H→D</text>
          <rect x="20" y="298" width="110" height="30" rx="6" fill="#efebff" stroke="#7c5cff"/>
          <text x="75" y="313" text-anchor="middle" dominant-baseline="central" font-size="10" fill="#5b3fd6" font-weight="600" font-family="-apple-system, sans-serif">满链路带宽</text>
          <rect x="170" y="298" width="110" height="30" rx="6" fill="#fde8ec" stroke="#e85d75"/>
          <text x="225" y="313" text-anchor="middle" dominant-baseline="central" font-size="10" fill="#e85d75" font-weight="600" font-family="-apple-system, sans-serif">吞吐降 20-50%</text>
        </svg>
      </div>
      <div class="bw-derive">
        <div class="bw-derive-head">通路对比推导链</div>
        <div class="bw-step"><span class="n">1</span><span class="t">useGdr=1: LOC_DEVMEM (显存)</span><span class="d">buffer 在 GPU</span></div>
        <div class="bw-step"><span class="n">2</span><span class="t">useGdr=0: LOC_HOSTMEM (host)</span><span class="d">buffer 在锁页内存</span></div>
        <div class="bw-step"><span class="n">3</span><span class="t">GDRDMA: GPU→NIC 直达</span><span class="d">0 次拷贝，0 CPU 介入</span></div>
        <div class="bw-step"><span class="n">4</span><span class="t">降级: GPU→Host→NIC</span><span class="d">2 次 D↔H 拷贝，CPU 介入</span></div>
        <div class="bw-step"><span class="n">5</span><span class="t">GDRDMA: regMr(CUDA) | 降级: regMr(HOST)</span><span class="d">RDMA 注册方式不同</span></div>
        <div class="bw-concl">
          <div>降级主因：<span class="k">nv_peermem 未加载</span> 或驱动失配</div>
          <div class="h">吞吐降 20-50%，延迟翻倍；排查优先级：nv_peermem > 驱动版本 > 环境变量 > IOMMU > PCIe 拓扑</div>
        </div>
        <div class="bw-legend">
          <span>GDRDMA <b>0 次拷贝</b></span>
          <span>降级 <b>2 次 D↔H</b></span>
          <span>差距 <b>吞吐降 20-50%</b></span>
        </div>
      </div>
    </div>
  </div>

</div>

## 一、源码公式

```c
// netRecvSetup / netSendSetup 关键逻辑
protoLoc[p] = resources->useGdr ? LOC_DEVMEM : LOC_HOSTMEM;
// useGdr=1: buffer 分配在显存 (cudaMalloc)，IB 直接 DMA 显存
// useGdr=0: buffer 分配在 host 锁页内存 (cudaHostAlloc)，需先 D→H 拷贝

INFO(NCCL_INIT|NCCL_NET, "Channel %02d : %d[%lx] -> %d[%lx] [receive] via NET/%s/%d%s",
     channelId, peerInfo->rank, peerInfo->busId, myInfo->rank, myInfo->busId,
     ncclNetName(), resources->netDev,
     resources->useGdr ? "/GDRDMA" : "");  // 日志后缀由此决定
```

`/GDRDMA` 后缀由 `useGdr` 标志决定。`useGdr=1` 时 buffer 在显存，IB 网卡通过 `nv_peermem` 直接 DMA 显存；`useGdr=0` 时 buffer 回退到 host 锁页内存，数据需先从显存拷贝到 host 再经网卡发出。

## 二、参数含义

| 量 | GDRDMA 路径 | 降级路径 |
|----|------------|---------|
| useGdr | 1 | 0 |
| buffer 位置 | `LOC_DEVMEM`（显存） | `LOC_HOSTMEM`（host 锁页内存） |
| buffer 分配 | `ncclCudaCalloc` | `ncclCudaHostCalloc` |
| RDMA 注册 | `regMr(gpuPtr, NCCL_PTR_CUDA)` | `regMr(hostPtr, NCCL_PTR_HOST)` |
| conn.direct | `NCCL_DIRECT_NIC` | 0 |

## 三、对比表

| 维度 | NET/IB/0/GDRDMA | NET/IB/0（降级） |
|------|----------------|-----------------|
| buffer 位置 | GPU 显存（`LOC_DEVMEM`） | Host 锁页内存（`LOC_HOSTMEM`） |
| 数据路径 | GPU 显存 → IB NIC → 网络 | GPU 显存 → cudaMemcpy → Host → IB NIC → 网络 |
| 额外拷贝 | 0 次 | 2 次（发 D→H，收 H→D） |
| CPU 介入 | 无 | 有（cudaMemcpy 占用 CPU+PCIe） |
| RDMA 注册 | `regMr(gpuPtr, NCCL_PTR_CUDA)` | `regMr(hostPtr, NCCL_PTR_HOST)` |
| 依赖 | `nv_peermem` 模块 + IB peer memory 接口 | 仅标准 IB verbs |
| 吞吐影响 | 满链路带宽 | 降 20-50%（受 PCIe+拷贝开销拖累） |
| 延迟影响 | 最低 | 约翻倍（多一次 D↔H 往返） |

## 四、GDRDMA 判定逻辑

`useGdr` 由 `ncclTopoCheckGdr` 决定，需同时满足以下条件：

1. **`nv_peermem` 模块已加载** — 检查 `/sys/kernel/mm/memory_peers/nv_mem/version` 存在
2. **IB 网卡支持 peer memory** — `ncclIbGdrSupport()` 返回成功
3. **GPU 显存能被 IB 注册** — 实际尝试 `ncclNetRegMr(gpuPtr, NCCL_PTR_CUDA)`，成功才设 `gdrSupport=1`
4. **GPU 与 NIC 的 PCIe 拓扑可达** — `ncclTopoCheckGdr` 检查两者在同一 PCIe 子树
5. **环境变量未禁用** — `NCCL_IB_GDR_SUPPORT` 未设为 0

任一条件不满足，`useGdr=0`，日志就只打印 `NET/IB/0` 而无 `/GDRDMA` 后缀。

```c
// ncclIbGdrSupport 检查 nv_peermem 模块
ncclResult_t ncclIbGdrSupport(int ibDev) {
  static int moduleLoaded = -1;
  if (moduleLoaded == -1) {
    moduleLoaded = (access("/sys/kernel/mm/memory_peers/nv_mem/version", F_OK) == -1) ? 0 : 1;
  }
  if (moduleLoaded == 0) return ncclSystemError;
  return ncclSuccess;
}

// ncclIbGetProperties 设置 ptrSupport
ncclResult_t ncclIbGetProperties(int dev, ncclNetProperties_t* props) {
  props->ptrSupport = NCCL_PTR_HOST;
  if (ncclIbGdrSupport(dev) != ncclSuccess) {
    INFO(NCCL_NET,"NET/IB : GPU Direct RDMA Disabled for HCA %d '%s' (no module)", ...);
  } else {
    props->ptrSupport |= NCCL_PTR_CUDA;
  }
  ...
}
```

## 五、降级排查清单

从 `GDRDMA` 降级到无 `GDRDMA`，按概率从高到低排查：

### 1. `nv_peermem` 模块未加载（最常见）

```bash
lsmod | grep nv_peer_mem     # 检查是否加载
ls /sys/kernel/mm/memory_peers/nv_mem/version  # 检查 sysfs
# 若缺失：modprobe nv_peer_mem 或重新安装 nvidia-peer-memory
```

### 2. NVIDIA 驱动更新后 `nv_peermem` 失效

驱动升级常导致 peermem 模块需要重新编译。检查版本匹配：

```bash
cat /proc/driver/nvidia/version  # NVIDIA 驱动版本
dpkg -l | grep nvidia-peer-memory  # peermem 包版本
# 不匹配时需重新编译安装 nvidia-peer-memory-dkms
```

### 3. `NCCL_IB_GDR_SUPPORT` 被显式设置

```bash
echo $NCCL_IB_GDR_SUPPORT   # 应为空或1
# 若为0：unset NCCL_IB_GDR_SUPPORT
```

### 4. IB 驱动更新后 peer memory 接口变化

多见于 OFED 升级后未重启：

```bash
ofed_info -s  # 检查 OFED 版本
# 升级 OFED 后需重启或重新加载 mlx5_core
```

### 5. IOMMU 被启用

IOMMU 会阻止 IB 网卡直接 DMA GPU 显存：

```bash
dmesg | grep -i iommu
# BIOS 中关闭 IOMMU 或加内核参数 iommu=off
```

### 6. GPU 与 NIC 不在同一 PCIe Root Complex

拓扑变更（如换了插槽或重新映射）：

```bash
nvidia-smi topo -m  # 查看 GPU 与 NIC 拓扑
# 确认 GPU 和 IB 网卡在同一 PCIe 子树
```

建议先查第 1、2 项，覆盖 80% 的降级场景。确认 `nv_peermem` 加载且 `nvidia-peer-memory` 包版本匹配当前 NVIDIA 驱动版本后，重启 RCCL 任务看日志是否恢复 `/GDRDMA` 后缀。

## 六、性能影响量化

以 200G InfiniBand 为例（单向理论 25 GB/s）：

| 消息大小 | GDRDMA busBw | 降级 busBw | 差距 |
|---------|-------------|-----------|------|
| 1 MB | ~20 GB/s | ~12 GB/s | 40% |
| 8 MB | ~24 GB/s | ~15 GB/s | 37% |
| 64 MB | ~25 GB/s | ~18 GB/s | 28% |
| 128 MB | ~25 GB/s | ~19 GB/s | 24% |

降级路径的瓶颈在于 PCIe 带宽（典型 16 GB/s × 2 = 32 GB/s 双向）与 `cudaMemcpy` 的额外开销，大消息时差距缩小但仍显著。

---

*生成时间：2026-07-06 · 基于 NCCL/RCCL 源码分析*
