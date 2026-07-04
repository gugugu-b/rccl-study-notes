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
- 手推 Ring AllReduce 的时间复杂度：`T = 2*(n-1)*S / (n*B)`
- 推导 busbw 修正因子 `2*(n-1)/n` 的来历
- 对比理论值与实测值（用 rccl-tests 数据），分析差距来源
- 理解为什么 ring 能把带宽利用率逼近硬件峰值

### 5.2 阅读算法执行源码（3小时）
- `src/collectives/` 目录：各集合操作的实现
  - 重点读 `all_reduce.cc`（host 侧调度）和对应的 device kernel
  - 理解 `ncclKernelAllReduceRing` 的执行逻辑
  - 理解 channel 如何切分数据并行流水线执行

- 理解算法选择逻辑：
  - 消息大小如何影响 ring vs tree 的选择
  - `nChannels`、`nPipeChannels` 如何动态决定
  - 在 `src/comm.cc` 或 `src/graph/` 中找到 channel 数量计算逻辑

### 5.3 阅读 Tree 算法实现（1.5小时）
- `src/collectives/all_reduce.cc` 中的 tree 变体
- 理解 tree 的两阶段：上行 reduce + 下行 broadcast
- 理解 tree 对小消息低延迟的优势
- 对比 ring 和 tree 在不同消息大小下的性能（用 rccl-tests 实测）

---

## 今日产出
- [ ] Ring AllReduce 数据流时序图（手画，4 rank 示例）
- [ ] Ring AllReduce 数学推导（完整公式）
- [ ] `ncclKernelAllReduceRing` 的执行流程文档
- [ ] Ring vs Tree 性能对比实测数据

---

## 思考题
1. Ring AllReduce 的两个阶段（scatter-reduce、allgather）各需要多少步？每步传输多少数据？
2. 为什么小消息用 tree 更好，大消息用 ring 更好？
3. 如果 rank 数不是 2 的幂，ring 和 tree 各有什么影响？
4. channel 数量如何影响大消息的吞吐？为什么不能无限增加 channel？

---

## 参考阅读
- RCCL 源码 `src/collectives/all_reduce.cc`、device kernel 文件
- [NCCL之Ring和Tree](https://blog.csdn.net/rjc_lihui/article/details/150060380)
- 当前项目 `doc/PERFORMANCE.md`（busbw 公式推导）
