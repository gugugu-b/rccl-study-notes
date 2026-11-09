# OpenMPI 7天深入学习计划

> 目标：从零开始系统掌握 OpenMPI 的架构设计、核心通信语义、MCA 底层插件机制、网络与传输层（UCX / RoCE / IB）、GPU-Aware 异构计算以及超算与大模型分布式集群下的性能调优与故障排查。
>
> 前置要求：具备 C/C++ 基础、熟悉 Linux 开发环境、理解多进程并发体系与网络基础。
>
> 适用场景：超算并行计算、多机大模型训练编排（作为 `mpirun` 启动器与带外通信底座）、GPU-Aware 异构加速。

---

## 知识架构全景

```
用户应用层 (HPC 模拟程序 / 大模型启动脚本 / GPU-Aware 应用)
   │
   ▼
MPI API 规范层 (MPI_Init, MPI_Send/Recv, MPI_Allreduce, MPI_Comm_split)
   │
   ▼
OMPI 顶层管理层 (Communicator, Group, Datatype, Request 状态机)
   │
   ▼
MCA 插件化架构层 (Modular Component Architecture)
   │
   ├───────────────────────────────┬───────────────────────────────┐
   ▼                               ▼                               ▼
PML (点对点消息管理层)          COLL (集合通信算法层)           OSC (单边通信层)
 ├── ucx (现代化统一卸载)        ├── tuned (动态选优算法)        ├── rdma
 └── ob1 (传统经典多协议)        ├── basic / hierarch            └── pt2pt
   │                               │
   ├───────────────────────────────┘
   ▼
底层传输与网络接口
   │
   ├── 节点内传输: BTL vader (CMA / XPMEM 跨进程零拷贝共享内存)
   ├── 现代化高性能网络: UCX (UCP/UCT) ──> RoCEv2 / InfiniBand / GPUDirect RDMA
   └── 传统网络: BTL tcp (套接字) / BTL self (回环)
   │
   ▼
底层运行时与操作系统支撑 (ORTE/PRRTE 进程生命周期 + OPAL 硬件拓扑感知 hwloc)
```

---

## 7 天学习路线总览

| 天数 | 主题 | 核心产出 | 独立学习卡片 |
|:---:|---|---|:---:|
| Day 1 | 环境搭建与架构认知 | 生产级编译安装 OpenMPI，跑通 Hello World，掌握 `mpirun` 核心调度与进程排布参数 | [Day 1 学习文档](Day1_环境搭建与架构认知.md) |
| Day 2 | 点对点通信与底层协议 | 吃透阻塞与非阻塞通信，深度剖析 Eager 与 Rendezvous 协议，手写 Ping-Pong 延迟带宽测试程序 | [Day 2 学习文档](Day2_点对点通信与底层协议.md) |
| Day 3 | 集合通信与通信器管理 | 掌握全部核心集合操作与 `MPI_IN_PLACE`，学会非阻塞集合通信，掌握 `MPI_Comm_split` 通信器划分 | [Day 3 学习文档](Day3_集合通信与通信器管理.md) |
| Day 4 | MCA 模块化架构深度剖析 | 剖析 OPAL/ORTE/OMPI 分层，掌握 Framework/Component/Module 三元关系，熟练运用 `ompi_info` 调控参数 | [Day 4 学习文档](Day4_MCA模块化架构深度剖析.md) |
| Day 5 | 网络与传输层深潜：PML/BTL/UCX | 理解经典 PML+BTL 与现代 PML ucx 模型，掌握 `btl_vader` 共享内存与 UCX 在 RoCE/IB 上的配置与排错 | [Day 5 学习文档](Day5_网络与传输层PML_BTL_UCX.md) |
| Day 6 | GPU-Aware MPI 与多卡异构 | 掌握显存指针直通原理（HIP/CUDA IPC 与 GDRDMA），编写 GPU Ping-Pong，理清与 RCCL/NCCL 的协作分工 | [Day 6 学习文档](Day6_GPU_Aware_MPI与多卡异构.md) |
| Day 7 | 性能调优、Profiling 与大规模故障排查 | 掌握 CPU/NUMA/GPU/网卡四位一体绑定，运行 OSU Micro-Benchmarks，掌握 PMPI 追踪与常见挂死故障定位 | [Day 7 学习文档](Day7_性能调优_Profiling与故障排查.md) |

---

## Day 1：环境搭建与架构认知

### 学习目标
- 理解 MPI 标准与 OpenMPI 开源实现的核心定位与历史沿革
- 掌握 OpenMPI 源码生产级编译与安装（启用 UCX、多线程并发与进程绑定支持）
- 编写并运行第一个 MPI 程序，掌握 `mpirun` 的映射（mapping）与绑定（binding）机制
- 搞清大模型多机多卡测试中 OpenMPI 作为作业启动器（Launcher）的机制

### 任务清单
- 确认系统基础开发工具链（gcc, g++, gfortran, autoconf, libhwloc, libnuma）
- 从官网下载源码并配置生产编译参数（`--enable-mpi-thread-multiple`、`--with-ucx` 等）
- 编写 `hello_mpi.c`，获取全局 Size、当前 Rank、主机名与系统 PID
- 实验 `mpirun` 的高级拓扑调度参数：`--map-by numa`、`--bind-to core`、`--report-bindings`
- 详细指引见：[Day 1 学习文档](Day1_环境搭建与架构认知.md)

---

## Day 2：点对点通信与底层协议

### 学习目标
- 深入理解阻塞与非阻塞通信（Non-blocking）的本质差异与生命周期管理
- 掌握 4 种发送模式（标准、同步、缓冲、就绪）的使用边界与死锁规避
- 剖析底层两大核心传输协议：**Eager（渴望）协议** 与 **Rendezvous（会合）协议**
- 手写 Ping-Pong 工具测量单机共享内存与跨机网络的延迟/带宽曲线

### 任务清单
- 剖析阻塞调用的本质以及循环双向发送导致的死锁根因
- 掌握非阻塞接口 `MPI_Isend`、`MPI_Irecv`、`MPI_Waitall` 与通信计算重叠
- 绘制 Eager 协议与 Rendezvous 协议的握手数据流时序对比图
- 编写 `ping_pong.c`，测得 8 字节往返单程延迟（$\mu\text{s}$）与大包带宽峰值
- 详细指引见：[Day 2 学习文档](Day2_点对点通信与底层协议.md)

---

## Day 3：集合通信与通信器管理

### 学习目标
- 熟练掌握 Broadcast、Scatter、Gather、Allgather、Reduce、Allreduce、AlltoAll 核心算子
- 理解 `MPI_IN_PLACE` 原地内存操作在大数据量下的节约机制
- 掌握 MPI-3 非阻塞集合通信（`MPI_Iallreduce` 等）与消除长尾木桶效应
- 掌握通信器（Communicator）切分机制：`MPI_Comm_split` 与 `MPI_Comm_split_type`

### 任务清单
- 梳理 8 种核心集合操作的数据流动图与参数定义
- 验证 `MPI_IN_PLACE` 在大规模梯度/张量聚合中的显存优化
- 编写程序利用 `MPI_Comm_split_type(..., MPI_COMM_TYPE_SHARED, ...)` 自动提取物理单机子域
- 实现两级分层归约（Hierarchical Reduction）：节点内先聚合，节点间 Leader 互联同步
- 详细指引见：[Day 3 学习文档](Day3_集合通信与通信器管理.md)

---

## Day 4：MCA 模块化架构深度剖析

### 学习目标
- 深入理解 OpenMPI 的三大分层体系：OPAL、ORTE/PRRTE、OMPI
- 彻底掌握 MCA（Modular Component Architecture）的设计哲学与生命周期
- 搞懂 Framework（框架）、Component（组件）、Module（模块）的三元关系
- 熟练使用 `ompi_info` 检索、分析和动态注入 MCA 运行时参数

### 任务清单
- 梳理 OPAL 底层支撑库、ORTE 运行时环境与 OMPI 上层规范的分工界限
- 理解 MCA 组件的加载探测、优先级评分与动态裁决机制
- 使用 `ompi_info --param <framework> all` 检索核心通信框架的可配置参数
- 掌握命令行 `--mca`、环境变量 `OMPI_MCA_` 与配置文件的优先级层级
- 详细指引见：[Day 4 学习文档](Day4_MCA模块化架构深度剖析.md)

---

## Day 5：网络与传输层深潜：PML、BTL 与 UCX

### 学习目标
- 掌握经典 PML ob1 + BTL 分层传输模型与现代 PML ucx 卸载模型的演进路径
- 深入掌握节点内极速共享内存传输：`btl_vader`（CMA、XPMEM 零拷贝机制）
- 掌握现代化高性能通信底座 **UCX（Unified Communication X）** 的集成与参数调优
- 掌握 RoCEv2 与 InfiniBand 在双机/多机集群上的网卡指定、GID 选路与排障

### 任务清单
- 对比经典 `PML ob1` 与现代 `PML ucx` 在内存队列匹配与网络硬件卸载上的技术差异
- 剖析 Linux 内核 CMA（Cross Memory Attach）在进程间内存拷贝上的零开销特性
- 掌握 UCX 核心环境变量：`UCX_NET_DEVICES`、`UCX_TLS`、`UCX_IB_GID_INDEX`
- 结合本仓库双机 RoCE/IB 实战日志定位跨机建连与网卡多轨聚合配置
- 详细指引见：[Day 5 学习文档](Day5_网络与传输层PML_BTL_UCX.md)

---

## Day 6：GPU-Aware MPI 与多卡异构计算

### 学习目标
- 搞懂传统 MPI 与 GPU-Aware MPI 的本质性能差异（避免 CPU Host 显存来回搬运）
- 剖析 GPU-Aware 底层加速原理：节点内 HIP/CUDA IPC 与跨节点 GPUDirect RDMA（GDR）
- 编写 GPU-Aware MPI 程序，直接使用设备显存指针进行点对点通信
- 深入理解 OpenMPI 与 RCCL/NCCL 的分工协同与互补关系

### 任务清单
- 绘制传统主机内存中转通信与 GPU-Aware 直通零拷贝的时序对比图
- 验证当前 OpenMPI / UCX 是否已具备 GPU 驱动与显存感知编译支持
- 编写 `gpu_ping_pong.cpp`（以 HIP/CUDA 设备指针传参），实测卡间与跨机显存直通吞吐
- 深入总结：在大模型分布式训练中为何 OpenMPI 主管控制面而 RCCL 接管数据面
- 详细指引见：[Day 6 学习文档](Day6_GPU_Aware_MPI与多卡异构.md)

---

## Day 7：性能调优、Profiling 与大规模故障排查

### 学习目标
- 彻底掌握 CPU 核绑定、NUMA 节点与网卡/GPU 物理亲和性调优
- 熟练使用超算工业界基准测试套件 **OSU Micro-Benchmarks（OMB）**
- 掌握 PMPI 分析接口与轻量级 Tracing 分析工具的使用
- 掌握大规模集群生产常见故障排查（Rank 挂起卡死、RDMA Retry 超时、SSH 环境变量丢失）

### 任务清单
- 制定 CPU/NUMA/GPU/网卡 四位一体亲和性绑定策略，消除跨 Socket 内存抖动
- 编译并运行 OSU Micro-Benchmarks（`osu_latency`、`osu_bw`、`osu_allreduce`）
- 编写 PMPI 拦截动态库，实现对集合通信耗时的无侵入自动化统计
- 归纳总结跨机非标端口 SSH、RDMA PFC/ECN 丢包重传超时与环境传递排障手册
- 详细指引见：[Day 7 学习文档](Day7_性能调优_Profiling与故障排查.md)

---

## 7天计划完结

回顾整个技术进阶路径：

| 天数 | 主题 | 核心收获 | 状态 |
|:---:|---|---|:---:|
| Day 1 | 环境搭建与架构认知 | 掌握生产级构建与进程排布参数调度 | [ ] |
| Day 2 | 点对点通信与底层协议 | 吃透非阻塞通信与 Eager/Rendezvous 握手机制 | [ ] |
| Day 3 | 集合通信与通信器管理 | 熟练运用 `MPI_IN_PLACE`、非阻塞集合与通信器切分 | [ ] |
| Day 4 | MCA 模块化架构深度剖析 | 读懂 OPAL/ORTE/OMPI 体系与 MCA 插件化决策机制 | [ ] |
| Day 5 | 网络与传输层深潜：PML/BTL/UCX | 搞懂 `btl_vader` 共享内存与 UCX 在 RoCE/IB 上的精细调控 | [ ] |
| Day 6 | GPU-Aware MPI 与多卡异构 | 掌握显存直通通信，理顺与 RCCL 的控制面/数据面分工 | [ ] |
| Day 7 | 性能调优、Profiling 与大规模排障 | 掌握硬件四位一体绑定、OSU 压测与生产级疑难排障 | [ ] |

---

## 附录

### A. 推荐资料汇总

#### 官方规范与项目文档
- [OpenMPI 官方文档站](https://docs.open-mpi.org/en/v5.0.x/)
- [MPI Forum 官方规范（MPI 4.0）](https://www.mpi-forum.org/docs/mpi-4.0/mpi40-report.pdf)
- [UCX 官方文档站](https://openucx.readthedocs.io/en/latest/)
- [OSU Micro-Benchmarks 项目主页](https://mvapich.cse.ohio-state.edu/benchmarks/)

#### 经典著作与论文
- *Using MPI: Portable Parallel Programming with the Message-Passing Interface* (MIT Press)
- *Using Advanced MPI: Modern Features of the Message-Passing Interface* (MIT Press)
- *Open MPI: A Flexible High Performance MPI* (EuroPVM/MPI 2004 创刊论文)

#### 本地参考与实战文档
- [OpenMPI 性能指标详解与评估基准](PERFORMANCE.md)
- [双机 RCCL RoCE 与 IB 实测](../../bw1100/双机_RCCL_RoCE_与_IB_测试.md)（分析 MPI 在双机训练中的拉起参数）
- [双机测试自动化脚本](../../../run-rccl-perf-suite.sh)（查看生产级 `mpirun` 参数传递范式）

### B. 常用调试与调优命令速查

```shell
# 1. 查看 OpenMPI 安装信息与所有编译参数
ompi_info

# 2. 精确查看某一框架（如 pml、btl、coll）的参数与默认值
ompi_info --param btl all --level 9
ompi_info --param pml all

# 3. 打印详细的进程与物理核绑定映射
mpirun -np 8 --report-bindings --map-by numa --bind-to core ./my_app

# 4. 强制指定使用 UCX 传输层并排除旧版 openib
mpirun --mca pml ucx --mca btl ^openib -H node1:8,node2:8 ./my_app

# 5. 指定 RoCEv2 网卡与 GID 索引
mpirun --mca pml ucx -x UCX_NET_DEVICES=mlx5_0:1 -x UCX_IB_GID_INDEX=3 ./my_app

# 6. 非标准 SSH 端口跨机执行（如端口 2222）
mpirun --mca plm_rsh_args "-p 2222" -H node1,node2 ./my_app

# 7. 开启 UCX 调试日志排查握手与传输错误
UCX_LOG_LEVEL=info mpirun -np 2 --mca pml ucx ./my_app
```

### C. 学习日志模板

```markdown
## Day X 学习日志 - YYYY-MM-DD

### 完成情况
- [ ] 任务 1：
- [ ] 任务 2：

### 关键收获与底层机制理解
1. 
2. 
3. 

### 遇到的问题与定位解决
1. 现象：
   原因：
   解决方案：

### 思考题答案
1. 
2. 
3. 

### 明日学习计划
- 
```
