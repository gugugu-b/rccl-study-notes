# 分布式并行通信学习导航

本目录汇集了分布式高性能计算（HPC）与 AI 大模型集群通信的系统化进阶学习资料。内容分为 **RCCL（GPU/DCU 集合通信）** 与 **OpenMPI（通用消息传递与集群调度）** 两大专题。

---

## 专题导航

| 模块 | 目录 | 核心主题 | 适用场景 |
|---|---|---|---|
| **RCCL 学习专题** | [`rccl/`](rccl/RCCL_7天学习计划.md) | GPU/DCU 卡间与跨机集合通信（Ring/Tree 算法、拓扑感知、Channel 并发、P2P/RoCE/IB 传输、Tuner 调优） | 大模型分布式训练（Megatron-LM、DeepSpeed、PyTorch DDP/FSDP）、集合通信算子选优 |
| **OpenMPI 学习专题** | [`openmpi/`](openmpi/OpenMPI_7天学习计划.md) | MPI-3/MPI-4 规范、MCA 插件式架构、点对点/集合通信、PML/BTL/UCX 传输层、GPU-Aware MPI、大规模排障 | 跨节点多进程拉起与编排、HPC 数值模拟、GPU-Aware 通信、分布式框架基础底座 |

---

## RCCL 与 OpenMPI 的协同关系

在现代 AI 分布式训练与高性能计算集群中，OpenMPI 与 RCCL 并非互斥，而是**高度互补的上下游协作关系**：

```
                    ┌──────────────────────────────────────────┐
                    │      集群资源调度 (Slurm / Kubernetes)    │
                    └─────────────────────┬────────────────────┘
                                          │ 资源分配
                                          ▼
                    ┌──────────────────────────────────────────┐
                    │       集群启动器 (OpenMPI mpirun / PRRTE) │
                    └───────┬──────────────────────────┬───────┘
                            │                          │
                 跨节点进程拉起 / 环境变量注入      带外通信 (Out-of-band Bootstrap)
                            │                          │ 交换 UniqueId 与网络地址
                            ▼                          ▼
              ┌──────────────────────────┐   ┌──────────────────────────┐
              │ 节点 0: Rank 0 ~ Rank 7   │   │ 节点 1: Rank 8 ~ Rank 15 │
              │                          │   │                          │
              │   GPU 0 ~ GPU 7          │   │   GPU 0 ~ GPU 7          │
              └─────────────┬────────────┘   └─────────────┬────────────┘
                            │                              │
                            └──────────────┬───────────────┘
                                           │
                                           ▼
                    ┌──────────────────────────────────────────┐
                    │  数据面高速集合通信 (RCCL AllReduce/AlltoAll)│
                    │   - 节点内: xGMI / 海光 HSL / PCIe P2P    │
                    │   - 节点间: RoCEv2 / IB GDRDMA (无 CPU 参与)│
                    └──────────────────────────────────────────┘
```

1. **控制面（Control Plane）**：`OpenMPI` 的 `mpirun` 或 `prun` 负责在所有物理机上拉起各 GPU 所属的计算进程，配置 CPU/NUMA 亲和性，并在进程初始化阶段（Bootstrap）提供可靠的带外 Socket/组播通道，协助各个 Rank 完成对端网络地址交换。
2. **数据面（Data Plane）**：一旦通信器建连完毕，所有的模型梯度同步与张量切片传输（AllReduce、ReduceScatter、AllGather、AlltoAll）均完全交由 `RCCL` 执行。数据通过 GPU 间高速互联总线（如海光 HSL、AMD xGMI、NVIDIA NVLink）及 RDMA 网卡（RoCE/IB）直通传输，彻底旁路操作系统与 CPU。
3. **混合协同（Hybrid Workflows）**：在传统科学计算或需要 CPU-GPU 协同交互的混合工作流中，`GPU-Aware OpenMPI` 亦可直接对显存指针进行操作，与 RCCL 并行不悖。

---

## 学习建议

- **如果你主要关注大模型训练与集合通信优化**：建议优先精读 [`rccl/RCCL_7天学习计划.md`](rccl/RCCL_7天学习计划.md)，并结合 [`rccl/PERFORMANCE.md`](rccl/PERFORMANCE.md) 掌握总线带宽（busBw）的分析方法。
- **如果你需要排查双机/多机 `mpirun` 启动失败、InfiniBand/RoCE 网卡选路、进程亲和性或 GPU-Aware 数据直传**：建议系统研读 [`openmpi/OpenMPI_7天学习计划.md`](openmpi/OpenMPI_7天学习计划.md)，尤其是 Day 4（MCA 架构）、Day 5（PML/BTL/UCX 网络）与 Day 6（GPU-Aware MPI）。
