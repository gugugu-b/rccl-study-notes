# RCCL 7天深入学习计划

> 目标：从零开始深入理解 AMD RCCL（ROCm Communication Collectives Library）的架构、算法与实现，能够独立阅读源码、定位性能问题、进行调优。
>
> 前置要求：具备 C/C++ 基础、了解 GPU 编程（HIP/CUDA）、熟悉 Linux 开发环境。
>
> 适用仓库：RCCL 源码（已迁移至 [ROCm/rocm-systems](https://github.com/ROCm/rocm-systems)）+ rccl-tests（当前项目）

---

## 总览

| 天数 | 主题 | 核心产出 |
|:---:|---|---|
| Day 1 | 环境搭建与感性认识 | ROCm 环境就绪，跑通 rccl-tests，看懂输出 |
| Day 2 | 集合操作语义与测试框架 | 理解 8 种集合操作，读懂 rccl-tests 源码结构 |
| Day 3 | RCCL 源码入门：初始化与通信器 | 搞清 `ncclCommInitRank` 全流程 |
| Day 4 | 拓扑探测与逻辑图构建 | 理解物理拓扑→逻辑拓扑（ring/tree）的映射 |
| Day 5 | 核心算法：Ring 与 Tree | 吃透 AllReduce 的 ring/tree 实现细节 |
| Day 6 | 传输层与 Channel 机制 | 理解 P2P/SHM/NET 传输与 channel 流水线 |
| Day 7 | 进阶主题与实战调优 | 掌握 Tuner 插件、Profiler，完成一次调优实践 |

---

## Day 1：环境搭建与感性认识

### 学习目标
- 搭建可运行的 ROCm + RCCL + rccl-tests 环境
- 跑通第一个集合通信测试，理解输出指标
- 建立"集合通信到底在干什么"的直觉

### 任务清单

#### 1.1 确认 ROCm 环境（1小时）
- 检查 ROCm 是否已安装：`hipconfig --version`、`/opt/rocm/.info/version`
- 检查 GPU 可见性：`rocm-smi`（应能看到 GPU 设备）
- 确认 HIP 编译器：`which hipcc`、`which amdclang++`
- 记录 ROCm 版本、GPU 型号（如 MI250/MI300）、架构代号（如 gfx90a/gfx942）

#### 1.2 编译 rccl-tests（1小时）
```shell
# 在当前项目目录下
make HIP_HOME=/opt/rocm NCCL_HOME=/opt/rocm -j$(nproc)
# 或使用 cmake
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/rocm ..
make -j$(nproc)
```
- 确认 `build/all_reduce_perf` 等可执行文件生成
- 如果编译失败，排查 HIP/RCCL 路径、GPU target 是否匹配

#### 1.3 跑通第一个测试（1小时）
```shell
# 单 GPU 基线
./build/all_reduce_perf -b 8 -e 128M -f 2 -g 1

# 多 GPU（如有 2/4/8 卡）
./build/all_reduce_perf -b 8 -e 128M -f 2 -g 8
```
- 观察输出表格的每一列含义
- 重点理解 `algbw`（算法带宽）和 `busbww`（总线带宽）的区别

#### 1.4 阅读性能文档（1小时）
- 精读 `doc/PERFORMANCE.md`，理解每种集合操作的 busbw 修正因子推导
- 自己用公式手算一次：8 GPU、128MB AllReduce 的理论 busbw 上限是多少

### 今日产出
- [ ] ROCm 环境信息记录表（版本、GPU、架构）
- [ ] rccl-tests 编译成功并能运行
- [ ] 一份 all_reduce_perf 的输出截图 + 自己对各列的注释
- [ ] 手算的带宽理论值

### 思考题
1. 为什么 `busbw` 比 `algbw` 更适合衡量集合通信的效率？
2. 当 GPU 数从 1 增加到 8 时，`algbw` 如何变化？`busbw` 呢？为什么？
3. 小消息（8B）和大消息（128MB）的性能瓶颈分别是什么？

### 参考资料
- 当前项目 `README.md` 和 `doc/PERFORMANCE.md`
- [RCCL 官方文档](https://rocm.docs.amd.com/projects/rccl/en/latest/)
- [RCCL GitHub 仓库](https://github.com/ROCm/rccl)（已迁移至 rocm-systems）

---

## Day 2：集合操作语义与测试框架

### 学习目标
- 彻底理解 8 种集合操作的数据流向与数学语义
- 读懂 rccl-tests 的代码架构（testColl / testEngine / threadArgs）
- 能修改测试参数并理解其对结果的影响

### 任务清单

#### 2.1 梳理集合操作语义（2小时）
对照 `src/` 下每个 `.cu` 文件，画出每种操作的数据流向图：

| 操作 | 文件 | 语义 | 是否有 root |
|---|---|---|:---:|
| AllReduce | `all_reduce.cu` | 所有 rank 得到相同的归约结果 | 否 |
| AllGather | `all_gather.cu` | 每个 rank 收集所有 rank 的数据 | 否 |
| ReduceScatter | `reduce_scatter.cu` | 归约后分散到各 rank | 否 |
| Broadcast | `broadcast.cu` | root 数据广播到所有 rank | 是 |
| Reduce | `reduce.cu` | 归约到 root | 是 |
| AlltoAll | `alltoall.cu` | 全交换 | 否 |
| Gather/Scatter | `gather.cu`/`scatter.cu` | 收集/分散 | 是 |
| SendRecv | `sendrecv.cu` | 点对点 | - |

- 每个操作画出 N=4 rank 的数据流示意图（手画即可）

#### 2.2 精读测试框架源码（2小时）
- 精读 `src/common.h`：重点理解 `testColl`、`testEngine`、`threadArgs` 三个结构体
- 精读 `src/common.cu`：理解 `TimeTest`、`Barrier`、`AllocateBuffs`、`InitData` 的作用
- 理解多进程×多线程×多GPU的层级关系：`totalRanks = nProcs × nThreads × nGpus`

#### 2.3 深入读一个完整测试（1小时）
以 `src/all_reduce.cu` 为例，逐行理解：
- `AllReduceGetCollByteCount`：如何计算发送/接收字节数
- `AllReduceInitData`：如何初始化输入和期望输出
- `AllReduceGetBw`：带宽如何计算（注意 `2*(n-1)/n` 因子）
- `AllReduceRunColl`：实际调用 `ncclAllReduce`
- `AllReduceRunTest`：如何遍历数据类型和操作类型

#### 2.4 实验不同参数（1小时）
```shell
# 不同数据类型
./build/all_reduce_perf -d half -g 4
./build/all_reduce_perf -d bfloat16 -g 4

# 不同归约操作
./build/all_reduce_perf -o sum -g 4
./build/all_reduce_perf -o max -g 4

# 正确性检查
./build/all_reduce_perf -c 5 -g 4

# 阻塞 vs 非阻塞
./build/all_reduce_perf -z 1 -g 4
```
- 记录不同参数对性能/正确性的影响

### 今日产出
- [ ] 8 种集合操作的数据流向图（手画或工具绘制）
- [ ] `common.h` 三个核心结构体的字段注释文档
- [ ] `all_reduce.cu` 逐行注释版
- [ ] 参数实验结果对比表

### 思考题
1. `testColl` 的回调函数设计为什么能做到"一套框架测所有操作"？
2. `InitData` 如何保证归约结果可精确预测？提示：看 `verifiable/verifiable.h`
3. 为什么 AllReduce 的 busbw 因子是 `2*(n-1)/n`，而 AllGather 是 `(n-1)/n`？

### 参考资料
- 当前项目 `src/common.h`、`src/all_reduce.cu`
- `verifiable/verifiable.h`（可验证归约的设计思路）

---

## Day 3：RCCL 源码入门：初始化与通信器

### 学习目标
- 获取并编译 RCCL 源码
- 理解通信器（`ncclComm_t`）的创建全流程
- 搞清 rank 分配、UniqueId 生成、进程组建立的机制

### 任务清单

#### 3.1 获取与编译 RCCL 源码（1.5小时）
```shell
git clone --recursive https://github.com/ROCm/rocm-systems.git
cd rocm-systems/rccl  # 或对应子目录
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```
- 如果新仓库结构不同，参考 `ROCm/rccl` 的 `develop_deprecated` 分支
- 确认 `librccl.so` 生成成功
- 用自编译的 RCCL 重新链接 rccl-tests，验证可运行

#### 3.2 阅读初始化流程（2.5小时）
按调用顺序阅读以下文件：

1. **API 入口**：`src/init.cc` 中的 `ncclCommInitRank`
   - 理解 `ncclCommInitAll`、`ncclCommInitRank`、`ncclCommInitRankConfig` 的关系
   - 跟踪 `ncclUniqueId` 的生成（`ncclGetUniqueId`）

2. **通信器结构体**：`src/nccl.h` 中的 `ncclComm` 定义
   - 找到 `struct ncclComm` 的完整定义（可能在 `src/nccl.h` 或内部头文件）
   - 记录关键字段：rank、nRanks、channels、transports、graph 等

3. **初始化主流程**：`ncclCommInitRank` 内部调用链
   - `bootstrap` 阶段：rank 间如何互相发现（socket/multicast）
   - `initTransports` 阶段：拓扑探测与传输建立（今天先了解入口，Day 4 深入）
   - `initComm` 阶段：channel 与 communicator 的最终建立

#### 3.3 理解 Bootstrap 机制（1小时）
- 阅读 `src/bootstrap.cc`（或对应文件）
- 理解 rank 0 如何通过 UniqueId 创建监听，其他 rank 如何连接
- 理解 MPI 模式下 bootstrap 的差异

### 今日产出
- [ ] RCCL 源码编译成功，能替换系统库运行 rccl-tests
- [ ] `ncclComm` 结构体字段注释文档
- [ ] 初始化流程图（从 `ncclCommInitRank` 到通信器就绪）
- [ ] Bootstrap 机制说明（1页）

### 思考题
1. `ncclUniqueId` 是如何保证跨节点唯一且可传递的？
2. 为什么初始化要区分 bootstrap、initTransports、initComm 三个阶段？
3. `ncclCommInitRank` 中的 `comm->rank` 和 MPI 的 rank 是什么关系？

### 参考阅读
- RCCL 源码 `src/init.cc`、`src/bootstrap.cc`
- [NCCL 源码导读 - init_transports_rank](https://blog.csdn.net/Chenzhinan1219/article/details/142878010)（NCCL 与 RCCL 架构相通）

---

## Day 4：拓扑探测与逻辑图构建

### 学习目标
- 理解 RCCL 如何探测系统物理拓扑（PCIe/xGMI/NUMA/网络）
- 理解如何从物理拓扑构建逻辑通信图（ring/tree）
- 掌握 `NCCL_DEBUG=GRAPH` 输出的解读

### 任务清单

#### 4.1 阅读拓扑探测代码（2小时）
- `src/topo.cc`（或 `src/graph/topo.cc`）：系统拓扑探测
  - 理解如何检测 GPU 间连接类型：P2P（xGMI/PCIe）、共享内存、网络
  - 理解 NUMA 距离、PCI 距离如何量化
  - 重点：AMD xGMI 与 NVIDIA NVLink 的差异（在代码中找 `xgmi` 或 `gmi` 相关逻辑）

- `src/graph/` 目录：图构建模块
  - `graph.cc`：图的节点和边的数据结构
  - `paths.cc`：路径计算（GPU 间最优路径）

#### 4.2 阅读 Ring/Tree 构建算法（2小时）
- `src/graph/ring.cc`：ring 逻辑拓扑构建
  - 理解如何搜索一个使总带宽最大的 ring 排列
  - 理解多 ring（双环、四环）的作用

- `src/graph/tree.cc`：tree 逻辑拓扑构建
  - 理解节点内 chain + 节点间 tree 的组合策略
  - 理解 tree 的 parent/child 关系如何决定数据流

#### 4.3 实战：解读 DEBUG 输出（1.5小时）
```shell
NCCL_DEBUG=GRAPH ./build/all_reduce_perf -g 8 -b 1M -e 1M -n 1
```
- 找到输出的拓扑信息：物理拓扑图、构建的 ring/tree、channel 数量
- 对照源码理解每一行日志的含义
- 尝试不同 GPU 数（1/2/4/8），观察拓扑变化

#### 4.4 对比 xGMI vs PCIe 场景（0.5小时）
- 如果环境有 xGMI 互联（MI250/MI300），对比有/无 xGMI 时的拓扑差异
- 在 `NCCL_DEBUG=GRAPH` 输出中找到 xGMI 连接的标记

### 今日产出
- [ ] 系统物理拓扑图（基于 `rocm-smi` 和 `NCCL_DEBUG=GRAPH`）
- [ ] Ring 构建算法的步骤说明
- [ ] Tree 构建算法的步骤说明
- [ ] 一份 `NCCL_DEBUG=GRAPH` 完整输出的注释版

### 思考题
1. 为什么 RCCL 要构建多 ring？单 ring 的带宽瓶颈在哪？
2. 节点内 ring + 节点间 ring 的组合，与节点内 chain + 节点间 tree 的组合，各适用于什么场景？
3. xGMI 比 PCIe 快多少？在拓扑图中如何体现？

### 参考阅读
- RCCL 源码 `src/topo.cc`、`src/graph/ring.cc`、`src/graph/tree.cc`
- [理解NCCL的Tree](https://blog.csdn.net/shanleo1986/article/details/137014604)
- [NCCL 拓扑与算法分析](https://blog.csdn.net/rjc_lihui/article/details/150060380)

---

## Day 5：核心算法：Ring 与 Tree

### 学习目标
- 彻底理解 Ring AllReduce 的分阶段执行（scatter-reduce + allgather）
- 理解 Tree AllReduce 的工作原理与适用场景
- 能对照源码看懂算法在 channel 上的执行流程

### 任务清单

#### 5.1 推导 Ring AllReduce 数学模型（1.5小时）
- 手推 Ring AllReduce 的时间复杂度：`T = 2*(n-1)*S / (n*B)`
- 推导 busbw 修正因子 `2*(n-1)/n` 的来历
- 对比理论值与实测值（用 rccl-tests 数据），分析差距来源
- 理解为什么 ring 能把带宽利用率逼近硬件峰值

#### 5.2 阅读算法执行源码（3小时）
- `src/collectives/` 目录：各集合操作的实现
  - 重点读 `all_reduce.cc`（host 侧调度）和对应的 device kernel
  - 理解 `ncclKernelAllReduceRing` 的执行逻辑
  - 理解 channel 如何切分数据并行流水线执行

- 理解算法选择逻辑：
  - 消息大小如何影响 ring vs tree 的选择
  - `nChannels`、`nPipeChannels` 如何动态决定
  - 在 `src/comm.cc` 或 `src/graph/` 中找到 channel 数量计算逻辑

#### 5.3 阅读 Tree 算法实现（1.5小时）
- `src/collectives/all_reduce.cc` 中的 tree 变体
- 理解 tree 的两阶段：上行 reduce + 下行 broadcast
- 理解 tree 对小消息低延迟的优势
- 对比 ring 和 tree 在不同消息大小下的性能（用 rccl-tests 实测）

### 今日产出
- [ ] Ring AllReduce 数据流时序图（手画，4 rank 示例）
- [ ] Ring AllReduce 数学推导（完整公式）
- [ ] `ncclKernelAllReduceRing` 的执行流程文档
- [ ] Ring vs Tree 性能对比实测数据

### 思考题
1. Ring AllReduce 的两个阶段（scatter-reduce、allgather）各需要多少步？每步传输多少数据？
2. 为什么小消息用 tree 更好，大消息用 ring 更好？
3. 如果 rank 数不是 2 的幂，ring 和 tree 各有什么影响？
4. channel 数量如何影响大消息的吞吐？为什么不能无限增加 channel？

### 参考阅读
- RCCL 源码 `src/collectives/all_reduce.cc`、device kernel 文件
- [NCCL之Ring和Tree](https://blog.csdn.net/rjc_lihui/article/details/150060380)
- 当前项目 `doc/PERFORMANCE.md`（busbw 公式推导）

---

## Day 6：传输层与 Channel 机制

### 学习目标
- 理解 RCCL 的传输抽象（transport）与具体实现
- 掌握 P2P、SHM、NET 三种传输的选择机制
- 理解 channel 的流水线执行模型

### 任务清单

#### 6.1 阅读传输层框架（2小时）
- `src/transport/` 目录结构
  - `transport.cc`：传输抽象接口
  - `p2p.cc`：GPU 间 P2P 传输（xGMI/PCIe）
  - `shm.cc`：节点内进程间共享内存传输
  - `net.cc`：节点间网络传输（IB/TCP）

- 理解 `sendProxy` / `recvProxy` 机制
  - 为什么需要 proxy 线程
  - GPU kernel 与 CPU proxy 如何协作

#### 6.2 深入 P2P 传输（1.5小时）
- 理解 GPU 间 P2P 直接访问的硬件基础（xGMI/PCIe P2P）
- 理解 `cudaIpcOpenMemHandle`（HIP 对应 API）的作用
- 在 `NCCL_DEBUG=GRAPH` 中确认 P2P 连接的建立
- 对比 xGMI 带宽与 PCIe 带宽的实测差异

#### 6.3 深入网络传输（1.5小时）
- `src/transport/net.cc` 或 `src/graph/xml.cc`
- 理解 IB Verbs 和 TCP socket 两种后端
- 理解 `ext-net` 插件机制：如何自定义网络传输
- 阅读 [NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)

#### 6.4 Channel 流水线机制（1小时）
- 理解 channel 是什么：一条独立的通信流水线
- 理解多 channel 并发如何提升带宽利用率
- 理解 `nChannels` 的计算逻辑（与 rank 数、拓扑、消息大小相关）
- 在 `NCCL_DEBUG=GRAPH` 中找到 channel 数量的输出

### 今日产出
- [ ] 传输层架构图（P2P/SHM/NET 的选择决策树）
- [ ] P2P vs SHM vs NET 带宽实测对比表
- [ ] Channel 流水线执行示意图
- [ ] `ext-net` 插件接口说明文档

### 思考题
1. 为什么节点内用 P2P/SHM，节点间用 NET？能不能统一？
2. proxy 线程为什么在 CPU 侧运行？如果完全在 GPU 侧做可以吗？
3. 8 GPU 节点内 AllReduce，通常会建几个 channel？为什么？
4. `ext-net` 插件解决什么问题？什么场景需要自定义网络传输？

### 参考阅读
- RCCL 源码 `src/transport/p2p.cc`、`src/transport/shm.cc`、`src/transport/net.cc`
- [RCCL NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)

---

## Day 7：进阶主题与实战调优

### 学习目标
- 掌握 RCCL Tuner 插件机制，能进行自动调优
- 学会使用 Profiler 进行性能分析
- 完成一次端到端的性能调优实践
- 了解 MSCCL、HIP Graph 集成等前沿方向

### 任务清单

#### 7.1 学习 Tuner 插件（2小时）
- 阅读 [RCCL Tuner 插件 API 文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-rccl-tuner-plugin-api.html)
- 理解 Tuner 如何动态选择：算法（ring/tree）、channel 数、协议（simple/ll/ll128）
- 阅读 `ext-tuner/example/` 下的示例代码
- 编译并运行一个 Tuner 示例，观察调优效果

#### 7.2 性能分析实战（2小时）
- 使用 `NCCL_DEBUG=VERSION` 对比不同配置下的算法选择
- 使用 ROCm Profiler（`rocprof`）或 RCCL 自带 profiler（`ext-profiler`）分析通信热点
- 实验以下调优手段并记录效果：
  ```shell
  # 环境变量调优
  NCCL_NCHANNELS=4 ./build/all_reduce_perf -g 8 -e 128M
  NCCL_BUFFSIZE=8388608 ./build/all_reduce_perf -g 8 -e 128M
  HSA_NO_SCRATCH_RECLAIM=1 ./build/all_reduce_perf -g 8 -e 128M  # MI300 专用
  ```
- 记录每个调优参数对 algbw/busbw 的影响

#### 7.3 HIP Graph 集成（1小时）
- 理解 HIP Graph 如何减少 CPU launch 开销
- 使用 rccl-tests 的 `-G` 参数测试 HIP Graph 模式
  ```shell
  ./build/all_reduce_perf -g 8 -b 8 -e 1M -G 10
  ```
- 对比有/无 Graph 时的小消息延迟

#### 7.4 了解前沿方向（1小时）
- **MSCCL/MSCCL++**：微软提出的自定义集合算法
  - RCCL 编译选项 `--enable-msccl-kernel`
  - 理解它如何突破 ring/tree 的理论极限
- **rocshmem 集成**：用于 AlltoAll 等 GDA（GPU-Driven Approach）场景
  - 在 RCCL git log 中搜索 `rocshmem` 相关 commit
- **多组并行**：rccl-tests 的 `NCCL_TESTS_SPLIT` 机制
  - 理解如何把 GPU 分组并行执行多个操作

#### 7.5 总结与知识体系梳理（1小时）
- 整理 7 天学习笔记，形成个人知识库
- 画一张 RCCL 完整架构图（从 API 到传输层）
- 列出尚未深入的问题清单，作为后续学习方向

### 今日产出
- [ ] Tuner 插件运行示例 + 效果对比
- [ ] 性能调优实验报告（参数 × 效果对比表）
- [ ] HIP Graph 性能对比数据
- [ ] RCCL 完整架构图（自绘）
- [ ] 后续学习问题清单

### 思考题
1. 在你的硬件环境下，AllReduce 的带宽瓶颈是 xGMI/PCIe 还是网络？如何验证？
2. 调整 `NCCL_NCHANNELS` 到什么值时性能最优？为什么不是越多越好？
3. HIP Graph 对小消息提升明显还是大消息？为什么？
4. MSCCL 相比传统 ring/tree 有什么本质区别？什么场景下有优势？

### 参考阅读
- [RCCL Tuner 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-rccl-tuner-plugin-api.html)
- [RCCL 环境变量文档](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/env-variables.html)
- [RCCL 使用技巧](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/rccl-usage-tips.html)
- RCCL `ext-tuner/example/`、`ext-profiler/` 源码

---

## 附录

### A. 推荐资料汇总

#### 官方文档
- [RCCL 官方文档站](https://rocm.docs.amd.com/projects/rccl/en/latest/)
- [RCCL API 规范](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/library-specification.html)
- [RCCL 环境变量](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/env-variables.html)
- [RCCL GitHub](https://github.com/ROCm/rccl)（已迁移至 [ROCm/rocm-systems](https://github.com/ROCm/rocm-systems)）

#### 源码导读（NCCL，架构相通）
- [从调用NCCL到深入NCCL源码](https://blog.csdn.net/Chenzhinan1219/article/details/142878010)
- [NCCL发布论文解读 - Ring和Tree](https://blog.csdn.net/rjc_lihui/article/details/150060380)
- [理解NCCL的Tree](https://blog.csdn.net/shanleo1986/article/details/137014604)
- [HCCL vs NCCL代码级对比](https://blog.csdn.net/weixin_75201252/article/details/157836986)

#### 学术资源
- xCCL: A Survey of Industry-Led Collective Communication Libraries for Deep Learning, JCST 2023

#### 本地资源（当前项目）
- `README.md`：rccl-tests 使用说明
- `doc/PERFORMANCE.md`：性能指标详解
- `src/common.h`：测试框架核心结构体
- `src/all_reduce.cu`：典型集合操作实现
- `verifiable/verifiable.h`：可验证归约机制

### B. 常用调试命令速查

```shell
# 版本与拓扑信息
NCCL_DEBUG=VERSION ./build/all_reduce_perf -g 8 -b 1M -e 1M -n 1

# 详细拓扑图
NCCL_DEBUG=GRAPH ./build/all_reduce_perf -g 8 -b 1M -e 1M -n 1

# 完整 trace
NCCL_DEBUG=TRACE ./build/all_reduce_perf -g 8 -b 1M -e 1M -n 1 2>&1 | head -200

# 指定 channel 数
NCCL_NCHANNELS=4 ./build/all_reduce_perf -g 8 -e 128M

# MI300 性能优化
HSA_NO_SCRATCH_RECLAIM=1 ./build/all_reduce_perf -g 8 -e 128M -f 2

# HIP Graph 模式
./build/all_reduce_perf -g 8 -b 8 -e 1M -G 10

# 输出 CSV/JSON
./build/all_reduce_perf -g 8 -e 128M -Z csv -x result.csv
./build/all_reduce_perf -g 8 -e 128M -Z json -x result.json

# 多组并行
NCCL_TESTS_SPLIT="MOD 2" ./build/all_reduce_perf -g 8 -e 128M
```

### C. 学习日志模板

每天学习结束后，填写以下日志：

```markdown
## Day X 学习日志 - YYYY-MM-DD

### 完成情况
- [ ] 任务1
- [ ] 任务2

### 关键收获
1. 
2. 
3. 

### 遇到的问题
1. 问题：
   解决方案：

### 思考题答案
1. 
2. 
3. 

### 明日计划调整
- 
```
