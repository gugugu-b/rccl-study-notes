# RCCL 7天深入学习计划

> 目标：从零开始深入理解 AMD / 海光 RCCL（ROCm Communication Collectives Library）的架构、算法与底层实现，能够独立阅读源码、定位通信性能瓶颈、进行全链路调优。
>
> 前置要求：具备 C/C++ 基础、了解 GPU 编程（HIP/CUDA）、熟悉 Linux 开发环境与多进程体系。
>
> 适用代码：本工作区内置 `rccl/`（RCCL 源码）与 `rccl-tests/`（集合通信性能测试套件），支持 AMD ROCm 与海光 Hygon DCU / DTK 双平台开发。

---

## 知识架构全景

```
用户 API (ncclAllReduce, ncclAllGather 等)
   │
   ▼
任务下发与调度 (rccl/src/collectives.cc, rccl/src/enqueue.cc)
   │
   ▼
拓扑感知与图计算 (rccl/src/graph/: topo.cc, search.cc, rings.cc, trees.cc, tuning.cc)
   │
   ├───────────────────────────────┐
   ▼                               ▼
通信通道 (Channels)             通信协议 (Protocols)
   │                               │
   │  ┌─────────────────────────┐  │ (Simple / LL / LL128)
   │  │ Channel 0 ~ Channel N-1 │  │
   │  └─────────────────────────┘  │
   ▼                               ▼
传输层抽象 (rccl/src/transport.cc, rccl/src/proxy.cc)
   │
   ├── P2P 传输 (rccl/src/transport/p2p.cc: xGMI / HSL / PCIe P2P, HIP IPC)
   ├── SHM 传输 (rccl/src/transport/shm.cc: 节点内主机共享内存中转)
   └── NET 传输 (rccl/src/transport/net_ib.cc, net_socket.cc: RoCE / IB Verbs / Socket)
   │
   ▼
设备端内核执行 (rccl/src/device/: all_reduce.h, prims_simple.h, prims_ll.h)
```

---

## 7 天学习路线总览

| 天数 | 主题 | 核心产出 | 独立学习卡片 |
|:---:|---|---|:---:|
| Day 1 | 环境搭建与感性认识 | 加速卡环境就绪，编译并跑通 rccl-tests，看懂性能输出 | [Day 1 学习文档](Day1_环境搭建与感性认识.md) |
| Day 2 | 集合操作语义与测试框架 | 理解 8 种核心集合操作与扩展算子，精读测试框架源码结构 | [Day 2 学习文档](Day2_集合操作语义与测试框架.md) |
| Day 3 | 初始化与通信器 | 搞懂 `ncclCommInitRank`、`struct ncclComm` 与 Bootstrap 握手机制 | [Day 3 学习文档](Day3_初始化与通信器.md) |
| Day 4 | 拓扑探测与逻辑图构建 | 理解物理拓扑探测（PCIe/xGMI/HSL/NUMA）到 Ring/Tree 逻辑图构建 | [Day 4 学习文档](Day4_拓扑探测与逻辑图构建.md) |
| Day 5 | 核心算法 Ring 与 Tree | 推导数学模型，剖析 AllReduce 在 Host/Device 源码级两阶段与树形实现 | [Day 5 学习文档](Day5_核心算法Ring与Tree.md) |
| Day 6 | 传输层与 Channel 机制 | 理解 P2P/SHM/NET 传输抽象、CPU Proxy 机制与多通道流水线模型 | [Day 6 学习文档](Day6_传输层与Channel机制.md) |
| Day 7 | 进阶主题与实战调优 | 掌握 Tuner 插件、Profiler 分析通信热点，完成软硬件参数调优 | [Day 7 学习文档](Day7_进阶主题与实战调优.md) |

---

## Day 1：环境搭建与感性认识

### 学习目标
- 搭建可运行的 ROCm / DTK + RCCL + rccl-tests 环境
- 跑通第一个集合通信性能测试，理解输出各项指标含义
- 建立"集合通信到底在干什么"的系统直觉

### 任务清单

#### 1.1 确认加速卡与编译环境（1小时）
根据当前服务器硬件选择对应检查指令：

| 检查项 | AMD ROCm 平台 | 海光 Hygon DCU / DTK 平台 |
|---|---|---|
| 安装路径 | `/opt/rocm` | `/opt/dtk` |
| 版本查询 | `hipconfig --version`、`/opt/rocm/.info/version` | `hipconfig --version`、`/opt/dtk/.dtk_version` |
| 设备拓扑与可见性 | `rocm-smi` | `hy-smi` |
| 编译器 | `which hipcc`、`which amdclang++` | `which hipcc`、`which clang++` |
| 典型硬件架构 | MI250X (gfx90a) / MI300X (gfx942) | BW1100 / BW150 / K100_AI (gfx906/gfx928) |

- 记录当前环境的 ROCm/DTK 版本、GPU/DCU 型号与架构代号。

#### 1.2 编译 rccl-tests（1小时）
rccl-tests 位于仓库的 `rccl-tests/` 子目录下：

```shell
# 进入 rccl-tests 源码目录
cd rccl-tests

# 方式一：Makefile 直接编译
# AMD ROCm 环境：
make HIP_HOME=/opt/rocm NCCL_HOME=/opt/rocm -j$(nproc)
# 海光 DTK 环境：
make HIP_HOME=/opt/dtk NCCL_HOME=/opt/dtk -j$(nproc)

# 方式二：CMake 编译
mkdir -p build && cd build
# AMD ROCm：
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/rocm ..
# 海光 DTK：
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/dtk ..
make -j$(nproc)
```
- 确认 `build/all_reduce_perf` 等可执行文件生成成功。
- 如果编译失败，排查 `HIP_HOME`、`NCCL_HOME` 路径以及 GPU Target 架构配置。

#### 1.3 跑通第一个测试（1小时）
在 `rccl-tests/build` 目录下运行：
```shell
# 单卡基线测试（验证基本运行）
./all_reduce_perf -b 8 -e 128M -f 2 -g 1

# 多卡基线测试（如有 2/4/8 卡）
./all_reduce_perf -b 8 -e 128M -f 2 -g 8
```
- 观察输出表格的每一列含义：`size`、`count`、`type`、`redop`、`root`、`time`、`algbw`、`busbw`、`#wrong`。
- 重点理解 `algbw`（算法带宽）和 `busbw`（总线带宽）的区别。

#### 1.4 阅读性能文档（1小时）
- 精读 [带宽指标说明](PERFORMANCE.md)，理解每种集合操作的 busbw 修正因子推导。
- 自己用公式手算一次：8 卡、128MB AllReduce 的理论 busbw 上限是多少。

### 今日产出
- [ ] 加速卡环境信息记录表（ROCm/DTK 版本、卡型、架构）
- [ ] rccl-tests 编译成功并能独立运行
- [ ] 一份 `all_reduce_perf` 的输出日志 + 对各列含义的注释
- [ ] 理论带宽手算演练笔记

### 思考题
1. 为什么 `busbw` 比 `algbw` 更适合跨卡数横向衡量集合通信的效率？
2. 当 GPU 数从 1 增加到 8 时，`algbw` 如何变化？`busbw` 呢？为什么？
3. 小消息（8B）和大消息（128MB）的性能瓶颈分别是什么？

### 参考资料
- [rccl-tests 使用说明](../../../rccl-tests/README.md)
- [带宽指标说明](PERFORMANCE.md)
- [RCCL 官方文档](https://rocm.docs.amd.com/projects/rccl/en/latest/)

---

## Day 2：集合操作语义与测试框架

### 学习目标
- 彻底理解各集合操作的数据流向、数学语义与适用场景
- 读懂 rccl-tests 测试套件的代码架构（`testColl` / `testEngine` / `threadArgs`）
- 掌握参数调控对测试行为和性能数据的影响

### 任务清单

#### 2.1 梳理集合操作语义（2小时）
对照 `rccl-tests/src/` 下每个 `.cu` 文件，梳理通信算子：

| 操作 | 文件（位于 `rccl-tests/src/`） | 数学语义 | 是否有 root |
|---|---|---|:---:|
| AllReduce | `all_reduce.cu` | 所有 rank 协同归约，全员得到相同归约结果 | 否 |
| AllGather | `all_gather.cu` | 每个 rank 收集所有 rank 的数据切片 | 否 |
| ReduceScatter | `reduce_scatter.cu` | 协同归约后按 rank 分块分散存储 | 否 |
| Broadcast | `broadcast.cu` | root 数据单向广播复制到所有 rank | 是 |
| Reduce | `reduce.cu` | 所有 rank 数据归约并汇聚到单一 root | 是 |
| AlltoAll | `alltoall.cu` | 全交换（每个 rank 向其他所有 rank 发送不同切片） | 否 |
| Gather / Scatter | `gather.cu` / `scatter.cu` | 汇聚到 root / 从 root 分散分发 | 是 |
| SendRecv | `sendrecv.cu` | 点对点双向传输通道 | - |
| AlltoAllv / HyperCube | `alltoallv.cu` / `hypercube.cu` | 变长全交换 / 超立方体通信（扩展算子） | 否 |

- 每个操作画出 $N=4$ rank 的数据流示意图。

#### 2.2 精读测试框架源码（2小时）
- 精读 `rccl-tests/src/common.h`：重点理解 `testColl`（算子接口）、`testEngine`（运行引擎）、`threadArgs`（线程/进程参数上下文）三个核心结构体。
- 精读 `rccl-tests/src/common.cu`：理解 `TimeTest`、`Barrier`、`AllocateBuffs`、`InitData` 的调度链路。
- 理解测试拓扑的层级抽象：`totalRanks = nProcs × nThreads × nGpus`。

#### 2.3 深入阅读典型测试用例（1小时）
以 `rccl-tests/src/all_reduce.cu` 为例，逐函数理解：
- `AllReduceGetCollByteCount`：计算发送、接收字节数与显存偏移
- `AllReduceInitData`：初始化输入数据与校验期望值
- `AllReduceGetBw`：带宽计算逻辑与 `2*(n-1)/n` 修正因子
- `AllReduceRunColl`：调用底层 `ncclAllReduce`
- `AllReduceRunTest`：遍历数据类型与归约算子

#### 2.4 实验不同参数（1小时）
在 `rccl-tests/build` 目录下运行：
```shell
# 不同数据类型
./all_reduce_perf -d half -g 4
./all_reduce_perf -d bfloat16 -g 4

# 不同归约操作
./all_reduce_perf -o sum -g 4
./all_reduce_perf -o max -g 4

# 正确性检查（验证前 5 个数据包）
./all_reduce_perf -c 5 -g 4

# 阻塞 vs 非阻塞模式
./all_reduce_perf -z 1 -g 4
```
- 观察并记录不同数据类型与归约操作对带宽与延迟的影响。

### 今日产出
- [ ] 8 种核心集合操作的数据流向示意图
- [ ] `rccl-tests/src/common.h` 核心结构体字段分析笔记
- [ ] `rccl-tests/src/all_reduce.cu` 流程分析文档
- [ ] 测试参数实验对比表

### 思考题
1. `testColl` 的回调函数设计为什么能做到"一套框架测所有操作"？
2. `InitData` 如何保证归约结果可精确预测？（参考 `rccl-tests/verifiable/verifiable.h`）
3. 为什么 AllReduce 的 busbw 因子是 `2*(n-1)/n`，而 AllGather 是 `(n-1)/n`？

### 参考资料
- [common.h](../../../rccl-tests/src/common.h)、[all_reduce.cu](../../../rccl-tests/src/all_reduce.cu)
- [verifiable.h](../../../rccl-tests/verifiable/verifiable.h)
- [带宽指标说明](PERFORMANCE.md)

---

## Day 3：RCCL 源码入门：初始化与通信器

### 学习目标
- 掌握本地 `rccl/` 源码的编译与调试环境配置
- 理解通信器（`ncclComm_t`）创建的完整生命周期
- 搞清 Rank 分配、UniqueId 生成与多进程/多节点 Bootstrap 握手机制

### 任务清单

#### 3.1 获取与编译本地 RCCL 源码（1.5小时）
本工作区已在根目录下内置了 `rccl/` 源码子模块：

```shell
cd rccl
mkdir -p build && cd build

# AMD ROCm 环境编译：
CXX=/opt/rocm/llvm/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/rocm ..
make -j$(nproc)

# 海光 DTK 环境编译：
CXX=/opt/dtk/llvm/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/dtk ..
make -j$(nproc)
```
- 确认编译产物 `build/lib/librccl.so` 生成成功。
- 用自编译库注入运行：`LD_LIBRARY_PATH=$(pwd)/lib:$LD_LIBRARY_PATH ./all_reduce_perf -g 2`。

#### 3.2 阅读初始化流程（2.5小时）
按调用链跟踪初始化流程：

1. **API 入口**：`rccl/src/init.cc` 中的 `ncclCommInitRank`
   - 理解 `ncclCommInitAll`、`ncclCommInitRank`、`ncclCommInitRankConfig` 的功能与边界
   - 跟踪 `ncclUniqueId` 的生成（`ncclGetUniqueId`）

2. **通信器内部结构体**：`rccl/src/include/comm.h`
   - 注意：公开头文件 `nccl.h.in` 中只有不透明指针 `typedef struct ncclComm* ncclComm_t;`，核心结构体 `struct ncclComm` 位于内部头文件 **`rccl/src/include/comm.h`**。
   - 重点研读字段：
     - `rank`、`nRanks`、`cudaDev`：节点内/全局编号与设备映射
     - `channels[MAXCHANNELS]`、`nChannels`：通信通道数组
     - `topo`：节点拓扑系统句柄
     - `peerInfo`、`bootstrap`：对端连接与带外通信信息

3. **初始化核心三阶段**：
   - `bootstrap` 阶段：通过 Socket 交换各 Rank 的对端网络与设备信息
   - `initTransportsRank` 阶段：拓扑探测与通信图构建（Day 4 深入）
   - `initComm` 阶段：为 Channel 分配环形/树形通信结构与 Ring Buffer

#### 3.3 理解 Bootstrap 机制（1小时）
- 阅读 `rccl/src/bootstrap.cc`
- 理解 Rank 0 如何创建监听 Socket，其他 Rank 如何根据 UniqueId 中的 IP/Port 连接握手
- 理解环形/全收集组播如何分发全局 Rank 寻址信息
- 对比非 MPI 独立进程模式与 MPI 模式下 Bootstrap 的差异

### 今日产出
- [ ] 本地 RCCL 源码成功编译并验证链接
- [ ] `struct ncclComm` 核心字段注释笔记
- [ ] 通信器初始化时序图（从 API 调用到通信就绪）
- [ ] Bootstrap 握手机制剖析文档（1页）

### 思考题
1. `ncclUniqueId` 是如何保证跨节点唯一且可传递的？
2. 为什么通信器初始化要严格分为 bootstrap、initTransports、initComm 三个阶段？
3. `ncclCommInitRank` 中的 `comm->rank` 与操作系统进程 PID、MPI Rank 是什么对应关系？

### 参考阅读
- [init.cc](../../../rccl/src/init.cc)、[bootstrap.cc](../../../rccl/src/bootstrap.cc)、[comm.h](../../../rccl/src/include/comm.h)
- [从调用NCCL到深入NCCL源码](https://blog.csdn.net/Chenzhinan1219/article/details/142878010)

---

## Day 4：拓扑探测与逻辑图构建

### 学习目标
- 理解 RCCL 如何探测系统物理拓扑（PCIe 交换层级、xGMI/HSL 链路、NUMA、网卡）
- 理解从物理硬件拓扑构建 Ring 与 Tree 逻辑通信图的搜索算法
- 掌握通过 `NCCL_DEBUG=GRAPH` 解读拓扑日志与通道分配

### 任务清单

#### 4.1 阅读拓扑探测代码（2小时）
- `rccl/src/graph/topo.cc` 与 `topo.h`：系统物理拓扑探测
  - 理解 GPU 间连接类型判定：P2P（xGMI / HSL / PCIe）、共享内存（SHM）、网络（NET）
  - 理解 NUMA 亲和性、PCIe Switch 树形层级与跳数距离的量化评估
  - 重点：AMD xGMI 与海光 HSL（Hygon StarLink）在代码中的探测分支（搜索 `xgmi`、`hsl`、`pci`）

- `rccl/src/graph/` 核心图模块：
  - `topo.h`：定义 `ncclTopoSystem`、`ncclTopoNode`、`ncclTopoLink` 物理图模型
  - `paths.cc`：全源最短路径与带宽矩阵计算（`ncclTopoComputePaths`）
  - `search.cc`：从拓扑图搜索最优通道配置（`ncclTopoSearch`）

#### 4.2 阅读 Ring/Tree 构建算法（2小时）
- `rccl/src/graph/rings.cc`：Ring 逻辑拓扑构建
  - 理解如何搜索一个使总带宽最大的 Ring 闭环排列（`ncclBuildRings`）
  - 理解多环并发（双环、四环、八环）在满载链路上的互补作用

- `rccl/src/graph/trees.cc`：Tree 逻辑拓扑构建
  - 理解节点内 Chain + 节点间 Tree 的分层树结构（`ncclBuildTree`）
  - 理解 Tree 的 Parent / Child 节点连接如何消除多跳累积延迟

- `rccl/src/graph/connect.cc` 与 `tuning.cc`：
  - 物理路径到 Channel 通道的最终绑定与参数整定

#### 4.3 实战：解读 DEBUG 输出（1.5小时）
在 `rccl-tests/build` 目录下运行：
```shell
NCCL_DEBUG=GRAPH ./all_reduce_perf -g 8 -b 1M -e 1M -n 1
```
- 查看输出的物理拓扑矩阵、Ring 环路节点序列、Tree 树形父子节点以及分配的 Channel 数量
- 对照源码日志逐行分析（如 `Ring 00 : 0 -> 1 -> 2 -> ...`）
- 尝试不同卡数（1/2/4/8），观察逻辑拓扑生成的变化

#### 4.4 对比高速互联 vs PCIe 场景（0.5小时）
- 对比高速链路卡型（如海光 BW1100 HSL 全互联、AMD MI300X xGMI）与纯 PCIe 机型（如海光 BW150）的拓扑日志差异
- 观察 `NCCL_DEBUG=GRAPH` 中标识的链路类型（`P2P/XGMI`、`P2P/HSL` 或 `P2P/PCI`）

### 今日产出
- [ ] 系统物理拓扑图（结合 `hy-smi` / `rocm-smi` 与 `NCCL_DEBUG=GRAPH`）
- [ ] Ring 搜索与构建算法流程说明
- [ ] Tree 构建算法与父子树划分说明
- [ ] 一份 `NCCL_DEBUG=GRAPH` 完整输出的注释解读

### 思考题
1. 为什么 RCCL 要构建多 Ring 并发？单 Ring 的物理带宽瓶颈在哪？
2. 节点内 Ring + 节点间 Ring 与节点内 Chain + 节点间 Tree 各自适用于什么通信场景？
3. 卡间高速互联（xGMI / HSL）比标准 PCIe 4.0/5.0 快多少？在拓扑图中如何体现权重差异？

### 参考阅读
- [topo.cc](../../../rccl/src/graph/topo.cc)、[rings.cc](../../../rccl/src/graph/rings.cc)、[trees.cc](../../../rccl/src/graph/trees.cc)、[search.cc](../../../rccl/src/graph/search.cc)
- [理解NCCL的Tree](https://blog.csdn.net/shanleo1986/article/details/137014604)
- [NCCL 拓扑与算法分析](https://blog.csdn.net/rjc_lihui/article/details/150060380)

---

## Day 5：核心算法：Ring 与 Tree

### 学习目标
- 彻底理解 Ring AllReduce 的两阶段（Scatter-Reduce + AllGather）分块流水线执行
- 理解 Tree AllReduce 的归约与广播模型及其小包低延迟优势
- 对照 Host 调度与 Device Kernel 源码看懂通信原语在 Channel 上的执行细节

### 任务清单

#### 5.1 推导 Ring AllReduce 数学模型（1.5小时）
- 手推 Ring AllReduce 的通信耗时公式：
  $$T = 2(n-1) \cdot \frac{S}{n \cdot B} + 2(n-1) \cdot \alpha$$
  （其中 $S$ 为数据总量，$n$ 为参与 Rank 数，$B$ 为单链路带宽，$\alpha$ 为单步延迟）
- 推导 busbw 修正因子 $2(n-1)/n$ 的来源
- 对比理论值与实测值（利用 rccl-tests 数据），分析小包到大包的带宽爬坡曲线
- 理解为何在大数据量下 Ring 能够使各链路保持 100% 满载

#### 5.2 阅读算法下发与 Kernel 源码（3小时）
- **Host 调度层**：
  - `rccl/src/collectives.cc`：集合操作 API 入口（`ncclAllReduce`）
  - `rccl/src/enqueue.cc`：`ncclEnqueueCheck`，将通信任务划分为切片，配置通道与核函数参数
  - 理解 Channel 是如何并行切分数据块进行流水线执行的

- **Device 执行层**：
  - `rccl/src/device/all_reduce.h`：AllReduce 设备端执行逻辑
  - `rccl/src/device/prims_simple.h`、`prims_ll.h`、`prims_ll128.h`：底层通信原语（`send`、`recv`、`recvReduceSend`、`recvCopySend`），理解 GPU 线程块如何通过 FIFO 环形缓冲区推进通信进度
  - `rccl/src/device/symmetric/all_reduce.cuh`：对称显存优化分支

- **算法与协议动态选优**：
  - `rccl/src/graph/tuning.cc`：根据消息大小 $S$、Rank 数量 $n$ 动态选取 Ring / Tree / CollNet 与 Simple / LL / LL128 协议

#### 5.3 阅读 Tree 算法实现（1.5小时）
- 阅读 `rccl/src/device/all_reduce.h` 中的 Tree 分支代码
- 理解 Tree 的两阶段执行：上行归约（Leaf $\to$ Parent $\to$ Root）与下行广播（Root $\to$ Parent $\to$ Leaf）
- 分析步数复杂度：步数为 $2 \lceil \log_2 n \rceil$，对比 Ring 的 $2(n-1)$，在节点多、数据包小（8B ~ 64KB）时 Tree 延迟明显占优
- 对比实测：通过环境变量 `NCCL_ALGO=RING` 与 `NCCL_ALGO=TREE` 进行性能对照

### 今日产出
- [ ] Ring AllReduce 4-Rank 数据流动与状态转移时序图
- [ ] Ring 与 Tree 算法的时间复杂度与带宽利用率推导笔记
- [ ] Device 端通信原语（`prims_simple.h`）同步机制解析文档
- [ ] Ring vs Tree 在不同数据包下的实测性能对照表

### 思考题
1. Ring AllReduce 的 Scatter-Reduce 与 AllGather 两阶段各需要多少步？每步传输多少字节？
2. 为什么小消息 Tree 延迟更低，而大消息 Ring 吞吐更高？
3. 如果 Rank 数量不是 2 的整数次幂，Ring 和 Tree 分别如何处理？
4. Channel 数量增加如何提升大包吞吐？为什么增加到一定数量后性能不再提升反而下降？

### 参考阅读
- [collectives.cc](../../../rccl/src/collectives.cc)、[enqueue.cc](../../../rccl/src/enqueue.cc)、[all_reduce.h](../../../rccl/src/device/all_reduce.h)、[prims_simple.h](../../../rccl/src/device/prims_simple.h)
- [NCCL之Ring和Tree](https://blog.csdn.net/rjc_lihui/article/details/150060380)
- [带宽指标说明](PERFORMANCE.md)

---

## Day 6：传输层与 Channel 机制

### 学习目标
- 掌握 RCCL 传输层（Transport）抽象框架与底层具体实现
- 搞清 P2P、SHM、NET 三种数据传输路径的选取策略与工作机制
- 理解 Channel 多通道流水线并发模型与 CPU Proxy 进度推进

### 任务清单

#### 6.1 阅读传输层框架（2小时）
- 传输层核心模块结构：
  - `rccl/src/transport.cc`：传输协议抽象层，定义 `struct ncclTransport` 与协议注册表 `ncclTransports`
  - `rccl/src/transport/p2p.cc`：卡间 P2P 直接内存读写（xGMI / HSL / PCIe P2P）
  - `rccl/src/transport/shm.cc`：节点内主机共享内存中转传输
  - `rccl/src/transport/net.cc`：跨节点网络通信抽象
  - `rccl/src/transport/net_ib.cc` / `net_ib_rocm.cc`：InfiniBand / RoCE RDMA 高性能网络传输
  - `rccl/src/transport/net_socket.cc`：TCP Socket 网络降级传输

- 理解 `sendProxy` / `recvProxy` 异步代理机制：
  - 阅读 `rccl/src/proxy.cc`
  - 为什么需要 CPU 侧 Proxy 线程：解耦 GPU 内核执行与网络/主机内存阻塞调用，处理异步 DMA 握手与进度推进
  - GPU Device Kernel（通过 FIFO 环形缓冲区指针更新）与 CPU Proxy（轮询推进进度）如何协调

#### 6.2 深入 P2P 传输（1.5小时）
- 理解 GPU 间 P2P 直接内存访问的硬件基础（xGMI、海光 HSL、PCIe P2P Direct Connect）
- 理解 HIP 内存共享 API：`hipIpcGetMemHandle` 与 `hipIpcOpenMemHandle` 的作用
- 在 `NCCL_DEBUG=GRAPH` 和 `NCCL_DEBUG=INIT` 中观察 P2P 连接的建立过程（如 `Channel xx : Rank x -> Rank y via P2P/direct pointer`）
- 对比高速互联（xGMI/HSL）带宽与 PCIe/SHM 带宽的实测差异

#### 6.3 深入网络传输（1.5小时）
- 阅读 `rccl/src/transport/net.cc` 与 `net_ib.cc`
- 理解 IB Verbs（Queue Pair、Completion Queue、Memory Region 注册、RDMA Read/Write/Send）与 TCP Socket 两种后端的选择
- 理解 GDR（GPUDirect RDMA）：GPU 显存直接通过网卡发送，绕过 CPU 主机内存中转
- 理解 `ext-net` 外部插件机制（位于 `rccl/ext-net/`）：第三方硬件与网络栈（如 RoCEv2 定制优化）如何挂载
- 阅读 [NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)

#### 6.4 Channel 流水线机制（1小时）
- 理解 Channel 的本质：一条包含独立 Ring/Tree 逻辑拓扑与专用 FIFO Ring Buffer 的通信流水线
- 理解多 Channel 并发如何提升硬件利用率（打满多计算单元 CU/SM 和多物理链路/网卡队列）
- 理解 `nChannels` 的计算逻辑（在 `rccl/src/graph/search.cc` 与 `tuning.cc` 中，受卡数、消息大小与物理拓扑限制）
- 在 `NCCL_DEBUG=GRAPH` 中确认实际初始化的 Channel 数量

### 今日产出
- [ ] 传输层架构图（P2P / SHM / NET 选择决策树与连接建立流程）
- [ ] P2P vs SHM vs NET 适用场景与带宽理论对比表
- [ ] GPU Kernel 与 CPU Proxy 异步通信时序示意图
- [ ] Channel 流水线切分与执行模型文档

### 思考题
1. 为什么节点内优先用 P2P/SHM，节点间用 NET？能不能统一？
2. Proxy 线程为什么在 CPU 侧运行？如果完全在 GPU 侧轮询网络网卡可以吗？有什么硬件门槛？
3. 8 GPU 节点内 AllReduce，通常会建几个 Channel？为什么不是越多越好？
4. `ext-net` 插件解决什么问题？什么场景需要自定义网络传输？

### 参考阅读
- [transport.cc](../../../rccl/src/transport.cc)、[p2p.cc](../../../rccl/src/transport/p2p.cc)、[shm.cc](../../../rccl/src/transport/shm.cc)、[net.cc](../../../rccl/src/transport/net.cc)、[proxy.cc](../../../rccl/src/proxy.cc)
- [RCCL NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)

---

## Day 7：进阶主题与实战调优

### 学习目标
- 掌握 RCCL Tuner 插件机制，实现通信策略的动态定制
- 学会使用性能分析工具定位通信热点与隐蔽瓶颈
- 完成一次端到端的多卡集合通信调优实战
- 了解 MSCCL、HIP Graph、GPU-Initiated 通信等前沿演进方向

### 任务清单

#### 7.1 学习 Tuner 插件（2小时）
- 阅读 [RCCL Tuner 插件 API 文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-rccl-tuner-plugin-api.html)
- 理解 Tuner 如何动态介入选择：算法（Ring / Tree / CollNet）、Channel 通道数、协议（Simple / LL / LL128）
- 阅读 `rccl/ext-tuner/example/` 下的示例代码（如 `plugin.cc`）
- 编译一个 Tuner 插件并配置 `NCCL_TUNER_PLUGIN` 加载，观察实测决策变化

#### 7.2 性能分析与环境变量调优实战（2小时）
- 使用 `NCCL_DEBUG=INFO` 或 `NCCL_DEBUG=VERSION` 查看通信器版本与运行态配置
- 使用加速卡 Profiler 工具分析通信耗时与 Kernel 占用：
  - AMD ROCm 平台：`rocprof`、`rccl/ext-profiler`
  - 海光 DTK 平台：`hipprof`
- 在 `rccl-tests` 构建目录下实验以下核心调优参数并记录效果：
  ```shell
  # 1. 调整通道数（默认通常随卡数拓扑变化，手动限制通道测试扩展性）
  NCCL_NCHANNELS=4 ./all_reduce_perf -g 8 -e 128M

  # 2. 调整传输环形缓冲区大小（默认 4MB，增大到 8MB/16MB 往往能提升大包吞吐）
  NCCL_BUFFSIZE=8388608 ./all_reduce_perf -g 8 -e 128M

  # 3. 强制指定算法与协议（排查阈值边界性能抖动）
  NCCL_ALGO=RING NCCL_PROTO=Simple ./all_reduce_perf -g 8 -e 128M
  NCCL_ALGO=TREE NCCL_PROTO=LL ./all_reduce_perf -g 8 -b 8 -e 64K

  # 4. 平台特异性优化
  # AMD ROCm / MI300：
  HSA_NO_SCRATCH_RECLAIM=1 ./all_reduce_perf -g 8 -e 128M
  # 海光 DCU / 双机 RoCE/IB（见本仓库 doc/bw1100 与 doc/transport 文档）：
  NCCL_NET_GDR_LEVEL=5 NCCL_CROSS_NIC=1 ./all_reduce_perf -g 8 -e 128M
  ```
- 记录每个调优参数对 `algbw` 与 `busbw` 的影响

#### 7.3 HIP Graph 集成（1小时）
- 理解 HIP Graph（类似 CUDA Graph）如何将通信 Kernel 的 Launch 与 Host 侧排队开销消除
- 使用 rccl-tests 的 `-G` 参数开启 HIP Graph 录制与回放：
  ```shell
  ./all_reduce_perf -g 8 -b 8 -e 1M -G 10
  ```
- 对比有/无 Graph 时小消息（8B ~ 64KB）的端到端延迟变化

#### 7.4 了解前沿方向（1小时）
- **MSCCL / MSCCL++**：微软提出的可编程自定义集合通信算法
  - RCCL 编译选项 `--enable-msccl-kernel`
  - 理解其如何针对异构非对称拓扑突破固定 Ring/Tree 的理论上限
- **rocshmem / GPU-Initiated 通信**：用于 AlltoAll 等细粒度通信场景
  - 在 RCCL 源码中关注 `dev_runtime.cc` 与 direct-access 演进
- **多组并行与拓扑切分**：rccl-tests 的 `NCCL_TESTS_SPLIT` 机制
  - 将单机 8 卡切分成两个独立 4 卡进程组并发测试

#### 7.5 总结与知识体系梳理（1小时）
- 整理 7 天学习笔记，形成系统性认知
- 绘制 RCCL 完整技术栈链路图（用户 API $\to$ Enqueue $\to$ Graph/Tuning $\to$ Channels $\to$ Transport $\to$ Device Kernel/Proxy）
- 列出未深入的疑难点与后续进阶方向

### 今日产出
- [ ] Tuner 插件编译与运行加载实验记录
- [ ] 核心参数调优实验报告（参数 × 带宽/延迟对比表）
- [ ] HIP Graph 小包延迟对比数据
- [ ] RCCL 全流程架构与数据流长图（自绘或文档总结）
- [ ] 后续学习与工程实践清单

### 思考题
1. 在你的硬件环境下，AllReduce 的带宽瓶颈是卡间互联（xGMI/HSL/PCIe）还是网络？如何验证？
2. 调整 `NCCL_NCHANNELS` 到什么值时性能最优？为什么不是越多越好？
3. HIP Graph 对小消息提升明显还是大消息？为什么？
4. MSCCL 相比传统 Ring/Tree 有什么本质区别？什么场景下有优势？

### 参考阅读
- [RCCL Tuner 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-rccl-tuner-plugin-api.html)
- [RCCL 环境变量文档](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/env-variables.html)
- [RCCL 使用技巧](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/rccl-usage-tips.html)
- 本地源码示例：`rccl/ext-tuner/example/`、`rccl/ext-profiler/`
- 本仓库实战文档：[BW1100 实战调优](../../bw1100/README.md)、[BW150 P2P 调优](../../transport/BW150_8GPU_P2P_tuning.md)

---

## 7天计划完结

回顾整个技术进阶路径：

| 天数 | 主题 | 核心收获 | 状态 |
|:---:|---|---|:---:|
| Day 1 | 环境搭建与感性认识 | 建立吞吐与延迟直觉，跑通基准测试 | [ ] |
| Day 2 | 集合操作语义与测试框架 | 掌握 8 种算子与 `rccl-tests` 框架设计 | [ ] |
| Day 3 | 初始化与通信器 | 读懂通信器创建、生命周期与带外握手 | [ ] |
| Day 4 | 拓扑探测与逻辑图构建 | 理解硬件物理图与逻辑拓扑映射算法 | [ ] |
| Day 5 | 核心算法：Ring 与 Tree | 掌握两阶段流水线与树形归约数学原理与 Kernel 实现 | [ ] |
| Day 6 | 传输层与 Channel 机制 | 搞清 P2P/SHM/NET 选路、Proxy 代理与通道并发 | [ ] |
| Day 7 | 进阶主题与实战调优 | 掌握性能剖析、Tuner 插件与端到端调优参数 | [ ] |

### 后续深入方向建议
- **框架集成**：研究 PyTorch `torch.distributed`（ProcessGroupNCCL）与 RCCL 的对接机制。
- **设备内核优化**：深入 device kernel 的硬件特定汇编与架构优化（如 Matrix Core、Wavefront 调度与双缓存）。
- **超大规模集群网络调优**：研究跨机多交换机胖树/Dragonfly 拓扑下的 RoCEv2 PFC/ECN 拥塞控制与 Adaptive Routing。
- **自定义集合通信**：尝试通过 MSCCL 或编写定制 RCCL Kernel 优化特异拓扑（如非对称 3-Ring、Cross-NUMA 拓扑）。

---

## 附录

### A. 推荐资料汇总

#### 官方文档与代码库
- [RCCL 官方文档站](https://rocm.docs.amd.com/projects/rccl/en/latest/)
- [RCCL API 规范](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/library-specification.html)
- [RCCL 环境变量参考](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/env-variables.html)
- [RCCL GitHub 仓库](https://github.com/ROCm/rocm-systems)（已迁移至 rocm-systems）

#### 源码导读与原理解读（NCCL / RCCL 架构相通）
- [从调用NCCL到深入NCCL源码](https://blog.csdn.net/Chenzhinan1219/article/details/142878010)
- [NCCL发布论文解读 - Ring和Tree](https://blog.csdn.net/rjc_lihui/article/details/150060380)
- [理解NCCL的Tree](https://blog.csdn.net/shanleo1986/article/details/137014604)
- [HCCL vs NCCL代码级对比](https://blog.csdn.net/weixin_75201252/article/details/157836986)

#### 本地核心代码入口
- [rccl-tests 测试套件](../../../rccl-tests/README.md)
- [测试框架头文件](../../../rccl-tests/src/common.h)
- [典型 AllReduce 测试实现](../../../rccl-tests/src/all_reduce.cu)
- [可验证归约实现](../../../rccl-tests/verifiable/verifiable.h)
- [通信器内部核心头文件](../../../rccl/src/include/comm.h)
- [拓扑探测与搜索](../../../rccl/src/graph/topo.cc)
- [性能指标与因子推导](PERFORMANCE.md)

### B. 常用调试与调优命令速查

```shell
# 1. 输出版本、初始化与拓扑信息
NCCL_DEBUG=INFO ./all_reduce_perf -g 8 -b 1M -e 1M -n 1
NCCL_DEBUG=GRAPH ./all_reduce_perf -g 8 -b 1M -e 1M -n 1

# 2. 详细通信 Trace（排查死锁或挂起）
NCCL_DEBUG=TRACE ./all_reduce_perf -g 8 -b 1M -e 1M -n 1 2>&1 | head -200

# 3. 手动指定 Channel 通道数
NCCL_NCHANNELS=4 ./all_reduce_perf -g 8 -e 128M

# 4. 手动指定通信算法与协议
NCCL_ALGO=RING NCCL_PROTO=Simple ./all_reduce_perf -g 8 -e 128M
NCCL_ALGO=TREE NCCL_PROTO=LL ./all_reduce_perf -g 8 -b 8 -e 64K

# 5. 调整环形缓冲区容量（默认 4MB，测试 8MB）
NCCL_BUFFSIZE=8388608 ./all_reduce_perf -g 8 -e 128M

# 6. HIP Graph 模式消除 Launch 开销
./all_reduce_perf -g 8 -b 8 -e 1M -G 10

# 7. 多组并行切分测试（如单机 8 卡切为 2 组 4 卡）
NCCL_TESTS_SPLIT="MOD 2" ./all_reduce_perf -g 8 -e 128M

# 8. 导出结果格式为 CSV 或 JSON
./all_reduce_perf -g 8 -e 128M -Z csv -x result.csv
./all_reduce_perf -g 8 -e 128M -Z json -x result.json
```

### C. 学习日志模板

每天学习结束后，建议按照以下模板记录学习日志：

```markdown
## Day X 学习日志 - YYYY-MM-DD

### 完成情况
- [ ] 任务 1：
- [ ] 任务 2：

### 关键收获与源码理解
1. 
2. 
3. 

### 遇到的问题与定位排查
1. 现象：
   原因：
   解决方案：

### 思考题答案
1. 
2. 
3. 

### 明日计划调整
- 
```
