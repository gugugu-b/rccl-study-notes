# Day 5：核心算法：Ring 与 Tree

> 所属计划：RCCL 7天深入学习计划

---

## 学习目标
- 彻底理解 Ring AllReduce 的分阶段执行（scatter-reduce + allgather）
- 理解 Tree AllReduce 的工作原理与适用场景
- 能对照源码看懂算法在 channel 上的执行流程

---

## 任务清单

### 5.1 推导 Ring AllReduce 数学模型（1.5小时）
- 手推 Ring AllReduce 的时间模型：
  $$\text{传输耗时 } T = 2(n-1) \cdot \frac{S}{n \cdot B} + 2(n-1) \cdot \alpha$$
  （其中 $S$ 为总字节量，$n$ 为 rank 数量，$B$ 为单向链路带宽，$\alpha$ 为每步启动与同步延迟）
- 推导 busbw 修正因子 $2(n-1)/n$ 的数学与物理来源（两阶段各传 $(n-1)/n \cdot S$ 数据）
- 对比理论值与实测值（用 rccl-tests 数据），分析不同消息长度下的差距来源
- 理解为什么 Ring 能在大数据量下将单链路带宽利用率逼近硬件理论极限

### 5.2 阅读算法执行与 Kernel 源码（3小时）
- **Host 侧下发与调度**：
  - `rccl/src/collectives.cc`：集合操作 API 入口（`ncclAllReduce`）
  - `rccl/src/enqueue.cc`：任务入队（`ncclEnqueueCheck`）、切分通道数据、填充 `ncclWork` 与启动 Device Kernel
  - 理解 Channel 是如何并行切分数据块进行流水线执行的

- **Device 侧 Kernel 与通信原语**：
  - `rccl/src/device/all_reduce.h`：AllReduce 在 Ring / Tree 下的设备端执行主逻辑
  - `rccl/src/device/prims_simple.h` / `prims_ll.h` / `prims_ll128.h`：通信原语（`send`、`recv`、`recvReduceSend`、`recvCopySend`），理解 GPU 线程块如何通过 FIFO 与对端同步
  - `rccl/src/device/symmetric/all_reduce.cuh`：高速互联对称内存加速实现

- **算法与协议选择逻辑**：
  - `rccl/src/graph/tuning.cc`：根据消息大小 $S$、rank 数量 $n$ 和物理拓扑动态选择算法（Ring vs Tree vs CollNet）与协议（Simple / LL / LL128）
  - 理解 `nChannels` 如何动态确定

### 5.3 阅读 Tree 算法实现（1.5小时）
- 阅读 `rccl/src/device/all_reduce.h` 中的 Tree 分支与 `rccl/src/graph/trees.cc`
- 理解 Tree 的两阶段执行：上行归约（Leaf $\to$ Parent $\to$ Root）与下行广播（Root $\to$ Parent $\to$ Leaf）
- 分析延迟优势：步数为 $2 \lceil \log_2 n \rceil$，相比 Ring 的 $2(n-1)$ 显著降低延迟，因此 Tree 是小数据包的优势算法
- 对比 Ring 和 Tree 在不同消息大小下的实测性能（用 `NCCL_ALGO=RING` 与 `NCCL_ALGO=TREE` 对照）

---

## 今日产出
- [ ] Ring AllReduce 数据流时序图（4 rank 示例，包含 Scatter-Reduce 与 AllGather 阶段）
- [ ] Ring AllReduce 数学推导笔记（包含每步传输量与理论时间）
- [ ] Device 端通信原语（`prims_simple.h`）执行流程与同步机制说明
- [ ] Ring vs Tree 性能对比实测数据表（不同数据包大小对照）

---

## 思考题
1. Ring AllReduce 的两个阶段（scatter-reduce、allgather）各需要多少步？每步传输多少数据？
2. 为什么小消息用 Tree 更好，大消息用 Ring 更好？
3. 如果 rank 数不是 2 的幂，Ring 和 Tree 各有什么影响？
4. Channel 数量如何影响大消息的吞吐？为什么不能无限增加 Channel？

---

## 参考阅读
- [collectives.cc](../../../rccl/src/collectives.cc)、[enqueue.cc](../../../rccl/src/enqueue.cc)、[all_reduce.h](../../../rccl/src/device/all_reduce.h)、[prims_simple.h](../../../rccl/src/device/prims_simple.h)
- [NCCL之Ring和Tree](https://blog.csdn.net/rjc_lihui/article/details/150060380)
- [带宽指标说明](PERFORMANCE.md)（busbw 公式推导）
