# Day 5：网络与传输层深潜：PML、BTL 与 UCX

> 所属计划：OpenMPI 7天深入学习计划
>
> 核心目标：搞清 OpenMPI 数据链路层核心传输机制，彻底弄懂节点内共享内存与跨机 InfiniBand / RoCE 的高性能网络选型与排错。

---

## 学习目标

- 搞懂 OpenMPI 两大点对点传输体系：**PML + BTL 经典分层模型** vs **PML ucx 现代化卸载模型**
- 深入掌握节点内极速共享内存传输：`btl_vader`（CMA、XPMEM）
- 掌握现代化高性能通信底座 **UCX（Unified Communication X）** 的集成与参数调控
- 掌握 RoCEv2 与 InfiniBand 在双机/多机集群上的网卡指定、GID 选路与排障实战

---

## 任务清单

### 5.1 传输层两大架构模型演进（1.5小时）

在 OpenMPI 发展史中，点对点传输层经历了从自研分层到工业界统一抽象的转变：

```
架构 A：经典分层模型 (PML ob1 + BTL)
┌─────────────────────────────────────────────────────────────┐
│                      PML (ob1)                              │
│  - 负责 MPI 消息 Tag 匹配、分片、乱序重组、Eager/会合控制      │
└───────────────┬───────────────────────────────┬─────────────┘
                │ 数据分片调度                  │ 数据分片调度
                ▼                               ▼
       ┌─────────────────┐             ┌─────────────────┐
       │   BTL (vader)   │             │   BTL (tcp/ib)  │
       │   节点内共享内存 │             │   以太网 / 传统网卡 │
       └─────────────────┘             └─────────────────┘

─────────────────────────────────────────────────────────────

架构 B：现代化统一卸载模型 (PML ucx / MTL ofi)
┌─────────────────────────────────────────────────────────────┐
│                      PML (ucx)                              │
│  - 极薄胶水层：直接将 MPI 匹配与传输任务全量移交外部专业通信库   │
└──────────────────────────────┬──────────────────────────────┘
                               │ 零额外开销直通
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 UCX (Unified Communication X)               │
│  - 包含 UCP (协议层), UCT (传输层), UCS (基础库)             │
│  - 原生统一支持：SHM (knem/cma), IB/RoCE (Verbs), GPU (GDR) │
└─────────────────────────────────────────────────────────────┘
```

- **为何现代 HPC 推荐 PML ucx**：
  在早期的 `PML ob1` 体系下，OpenMPI 内部维护匹配队列与分片；而在多网卡、超高并发与 GPU-Direct 场景下，由硬件厂商（NVIDIA、AMD、ARM）联合打造的 **UCX** 拥有更强大的多轨聚合（Multi-rail）、自适应路由（Adaptive Routing）与硬件减负能力。

### 5.2 节点内极速通信：BTL vader 机制（1.5小时）

当多个 Rank 运行在同一物理服务器内时，网络协议栈完全被旁路，OpenMPI 启用 `vader`（下一代共享内存组件）：

- **底层通信技术**：
  1. **CMA（Cross Memory Attach）**：Linux 内核系统调用 `process_vm_readv` / `process_vm_writev`，直接跨进程虚拟内存进行页表拷贝，完全无需中转缓冲区！
  2. **XPMEM（跨进程内存共享内核模块）**：超算系统常用，允许将其他进程的虚拟内存空间直接映射到本地页表。
  3. **标准 POSIX 共享内存 / 内存映射（mmap）**：无特殊内核特权时的标准回退机制。

- **Vader 常用调优参数**：
  ```shell
  # 设置共享内存的单段容量（默认 4MB，大包测试可调大到 16MB）
  mpirun --mca btl_vader_segment_size 16777216 -np 8 ./ping_pong
  ```

### 5.3 跨机高性能网络底座：UCX 配置与原理（2小时）

当需要使用 RoCEv2 或原生 InfiniBand 时，生产环境标准配置是通过 `pml ucx`：

- **UCX 的三层架构**：
  - **UCP (Protocols)**：处理 Eager / Rendezvous 握手、乱序重组、内存注册缓存（Memory Registration Cache）。
  - **UCT (Transports)**：直接调用底层驱动硬件接口（`ibv_post_send`、`cudaMemcpyPeer`、`hipMemcpyPeer`）。
  - **UCS (Services)**：提供数据结构、配置解析与性能计数器。

- **`mpirun` 调用 UCX 核心参数注入**：
  ```shell
  # 跨机 16 进程测试示例（双机各 8 卡/8 进程）
  mpirun -H node1:8,node2:8 \
      --mca pml ucx \
      --mca btl ^openib \
      -x UCX_NET_DEVICES=mlx5_0:1 \
      -x UCX_TLS=rc,sm,self \
      -x UCX_IB_GID_INDEX=3 \
      ./hello_mpi
  ```

| 参数项 | 说明 | 推荐调优值 / 典型排障项 |
|---|---|---|
| `UCX_NET_DEVICES` | 指定 UCX 绑定的物理 HCA 网卡设备与端口 | `mlx5_0:1`（排查多网卡错绑首选） |
| `UCX_TLS` | Transport Layers：指定允许使用的底层传输栈 | `rc,sm,self`（`rc`=可靠连接，`sm`=共享内存） |
| `UCX_IB_GID_INDEX`| RoCEv2 网络下的 GID 索引编号 | 通过 `show_gids` 确认 RoCEv2 对应条目序号 |
| `UCX_MAX_RNDV_RAILS` | 启用跨机多网卡聚合（Multi-rail）并发数 | 设为实际物理 RDMA 网卡数量（如 `2` 或 `4`） |

### 5.4 实战：双机 RoCE / InfiniBand 网络排障（1小时）

结合本工作区 [`doc/bw1100/双机_RCCL_RoCE_与_IB_测试.md`](../../bw1100/双机_RCCL_RoCE_与_IB_测试.md) 中的实战经验，总结 MPI 跨网卡排障标准步骤：

```shell
# 1. 检查物理链路与驱动状态
ibv_devinfo -v
rdma link show

# 2. 检查 RoCE GID 索引与 IP 绑定
show_gids

# 3. 开启 UCX 详细日志诊断网络建连
UCX_LOG_LEVEL=info mpirun -H node1:1,node2:1 --mca pml ucx ./hello_mpi 2>&1 | grep -i "transport"
```

---

## 今日产出

- [ ] 掌握 `PML ob1` 与 `PML ucx` 的本质区别与适用场景
- [ ] 掌握 Linux CMA 在 `btl_vader` 中的零拷贝原理
- [ ] 成功使用 `--mca pml ucx -x UCX_TLS=...` 运行跨机 MPI 程序
- [ ] 整理一份针对 RoCEv2 与原生 InfiniBand 的 UCX 环境变量速查表

---

## 思考题

1. 在 RoCEv2 环境下，为什么如果指定了错误的 `UCX_IB_GID_INDEX`（例如指向了 RoCEv1 或无效条目），跨机 MPI 通信会发生握手超时卡死？
2. 为什么在现代 OpenMPI 中运行 `mpirun` 时，经常看到提示建议 `--mca btl ^openib`？旧版 `openib` 有什么历史包袱？
3. `UCX_TLS=rc,ud,sm,self` 中的 `rc`（Reliable Connection）与 `ud`（Unreliable Datagram）各有什么优缺点？在超大规模几万个进程节点下，为什么通常会引入 `dc`（Dynamically Connected Transport）？

---

## 参考阅读

- [UCX 官方架构与参数文档](https://openucx.readthedocs.io/en/latest/)
- [OpenMPI UCX FAQ 指南](https://docs.open-mpi.org/en/v5.0.x/tuning-apps/networking/ucx.html)
- 本仓库实战参考：[`双机_RCCL_RoCE_与_IB_测试.md`](../../bw1100/双机_RCCL_RoCE_与_IB_测试.md)
