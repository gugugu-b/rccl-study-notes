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
- `src/transport/` 目录结构
  - `transport.cc`：传输抽象接口
  - `p2p.cc`：GPU 间 P2P 传输（xGMI/PCIe）
  - `shm.cc`：节点内进程间共享内存传输
  - `net.cc`：节点间网络传输（IB/TCP）

- 理解 `sendProxy` / `recvProxy` 机制
  - 为什么需要 proxy 线程
  - GPU kernel 与 CPU proxy 如何协作

### 6.2 深入 P2P 传输（1.5小时）
- 理解 GPU 间 P2P 直接访问的硬件基础（xGMI/PCIe P2P）
- 理解 `cudaIpcOpenMemHandle`（HIP 对应 API）的作用
- 在 `NCCL_DEBUG=GRAPH` 中确认 P2P 连接的建立
- 对比 xGMI 带宽与 PCIe 带宽的实测差异

### 6.3 深入网络传输（1.5小时）
- `src/transport/net.cc` 或 `src/graph/xml.cc`
- 理解 IB Verbs 和 TCP socket 两种后端
- 理解 `ext-net` 插件机制：如何自定义网络传输
- 阅读 [NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)

### 6.4 Channel 流水线机制（1小时）
- 理解 channel 是什么：一条独立的通信流水线
- 理解多 channel 并发如何提升带宽利用率
- 理解 `nChannels` 的计算逻辑（与 rank 数、拓扑、消息大小相关）
- 在 `NCCL_DEBUG=GRAPH` 中找到 channel 数量的输出

---

## 今日产出
- [ ] 传输层架构图（P2P/SHM/NET 的选择决策树）
- [ ] P2P vs SHM vs NET 带宽实测对比表
- [ ] Channel 流水线执行示意图
- [ ] `ext-net` 插件接口说明文档

---

## 思考题
1. 为什么节点内用 P2P/SHM，节点间用 NET？能不能统一？
2. proxy 线程为什么在 CPU 侧运行？如果完全在 GPU 侧做可以吗？
3. 8 GPU 节点内 AllReduce，通常会建几个 channel？为什么？
4. `ext-net` 插件解决什么问题？什么场景需要自定义网络传输？

---

## 参考阅读
- RCCL 源码 `src/transport/p2p.cc`、`src/transport/shm.cc`、`src/transport/net.cc`
- [RCCL NCCL Net 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-nccl.html)
