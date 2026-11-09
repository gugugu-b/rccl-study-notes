# Day 6：传输层与 Channel 机制

> 所属计划：RCCL 7天深入学习计划

---

## 学习目标
- 理解 RCCL 的传输抽象（transport）与具体实现
- 掌握 P2P、SHM、NET 三种传输的选择机制
- 理解 channel 的流水线执行模型

---

## 任务清单

### 6.1 阅读传输层框架（2小时）
- 传输层核心文件结构：
  - `rccl/src/transport.cc`：传输抽象层定义，注册各传输协议（`ncclTransports` 数组）
  - `rccl/src/transport/p2p.cc`：卡间 P2P 直接内存访问（xGMI / HSL / PCIe P2P）
  - `rccl/src/transport/shm.cc`：节点内跨进程 Host 共享内存中转
  - `rccl/src/transport/net.cc`：节点间网络传输入口抽象
  - `rccl/src/transport/net_ib.cc` / `net_ib_rocm.cc`：InfiniBand / RoCE RDMA 高性能网络传输
  - `rccl/src/transport/net_socket.cc`：TCP Socket 网络降级传输

- 理解 `sendProxy` / `recvProxy` 异步代理机制：
  - 阅读 `rccl/src/proxy.cc`
  - 为什么需要 CPU 侧 Proxy 线程：解耦 GPU 内核执行与网络/主机内存阻塞调用，处理异步 DMA 握手与进度推进
  - GPU Device Kernel（通过 FIFO 环形缓冲区指针更新）与 CPU Proxy（轮询推进进度）如何协调

### 6.2 深入 P2P 传输（1.5小时）
- 理解 GPU 间 P2P 直接内存访问的硬件基础（xGMI、海光 HSL、PCIe P2P Direct Connect）
- 理解 HIP 内存共享 API：`hipIpcGetMemHandle` 与 `hipIpcOpenMemHandle` 的作用
- 在 `NCCL_DEBUG=GRAPH` 和 `NCCL_DEBUG=INIT` 中观察 P2P 连接的建立过程（如 `Channel xx : Rank x -> Rank y via P2P/direct pointer`）
- 对比高速互联（xGMI/HSL）带宽与 PCIe/SHM 带宽的实测差异

### 6.3 深入网络传输（1.5小时）
- 阅读 `rccl/src/transport/net.cc` 与 `net_ib.cc`
- 理解 IB Verbs（Queue Pair、Completion Queue、Memory Region 注册、RDMA Read/Write/Send）与 TCP Socket 两种后端的选择
- 理解 GDR（GPUDirect RDMA）：GPU 显存直接通过网卡发送，绕过 CPU 主机内存中转
- 理解 `ext-net` 外部插件机制（位于 `rccl/ext-net/`）：第三方硬件与网络栈（如 RoCEv2 定制优化）如何挂载
- 阅读 [NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)

### 6.4 Channel 流水线机制（1小时）
- 理解 Channel 的本质：一条包含独立 Ring/Tree 逻辑拓扑与专用 FIFO Ring Buffer 的通信流水线
- 理解多 Channel 并发如何提升硬件利用率（打满多计算单元 CU/SM 和多物理链路/网卡队列）
- 理解 `nChannels` 的计算逻辑（在 `rccl/src/graph/search.cc` 与 `tuning.cc` 中，受卡数、消息大小与物理拓扑限制）
- 在 `NCCL_DEBUG=GRAPH` 中确认实际初始化的 Channel 数量

---

## 今日产出
- [ ] 传输层架构图（P2P / SHM / NET 选择决策树与连接建立流程）
- [ ] P2P vs SHM vs NET 适用场景与带宽理论对比表
- [ ] GPU Kernel 与 CPU Proxy 异步通信时序示意图
- [ ] Channel 流水线切分与执行模型文档

---

## 思考题
1. 为什么节点内优先用 P2P/SHM，节点间用 NET？能不能统一？
2. Proxy 线程为什么在 CPU 侧运行？如果完全在 GPU 侧轮询网络网卡可以吗？有什么硬件门槛？
3. 8 GPU 节点内 AllReduce，通常会建几个 Channel？为什么不是越多越好？
4. `ext-net` 插件解决什么问题？什么场景需要自定义网络传输？

---

## 参考阅读
- [transport.cc](../../../rccl/src/transport.cc)、[p2p.cc](../../../rccl/src/transport/p2p.cc)、[shm.cc](../../../rccl/src/transport/shm.cc)、[net.cc](../../../rccl/src/transport/net.cc)、[proxy.cc](../../../rccl/src/proxy.cc)
- [RCCL NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)
