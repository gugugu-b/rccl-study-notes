# RCCL 集合通信算子 · busBw 推导总览

> 本目录汇总 rccl-tests 中所有集合通信算子的 busBw（总线带宽）公式推导与手算过程。
> 统一场景：n = 8 GPU，rccl-tests 命令行 `-b 134217728`（count = 128 MB）
> 设 B = 单向链路带宽（如 XGMI/NVLink 单向峰值）

## 一、核心公式

所有算子的带宽计算遵循同一框架：

```
baseBw = 数据量 / T / 1e9      （GB/s，即 algBw）
busBw  = baseBw × factor
```

`factor` 是每个算子专属的归一化系数，用于把"算法带宽"折算到"等效单链路利用率"。

## 二、全算子公式速查表

| 算子 | 源码文件 | baseBw（数据量/T） | factor | busBw 上限 | 详细文档 |
|------|---------|-------------------|--------|-----------|---------|
| AllReduce | all_reduce.cu | count×ts | 2(n−1)/n | B | [AllReduce.md](AllReduce.md) |
| AllGather | all_gather.cu | count×ts×n | (n−1)/n | B | [AllGather.md](AllGather.md) |
| ReduceScatter | reduce_scatter.cu | count×ts×n | (n−1)/n | B | [ReduceScatter.md](ReduceScatter.md) |
| Broadcast | broadcast.cu | count×ts | 1 | B* | [Broadcast.md](Broadcast.md) |
| Reduce | reduce.cu | count×ts | 1 | B* | [Reduce.md](Reduce.md) |
| AlltoAll | alltoall.cu | count×ts×n | (n−1)/n | B | [AlltoAll.md](AlltoAll.md) |
| AlltoAllv | alltoallv.cu | count×ts×n | (n−1)/n | B | [AlltoAllv.md](AlltoAllv.md) |
| Scatter | scatter.cu | count×ts×n | (n−1)/n | B | [Scatter.md](Scatter.md) |
| Gather | gather.cu | count×ts×n | (n−1)/n | B | [Gather.md](Gather.md) |
| SendRecv | sendrecv.cu | count×ts | 1 | B | [SendRecv.md](SendRecv.md) |
| HyperCube | hypercube.cu | count×ts×(n−1) | 1 | B | [HyperCube.md](HyperCube.md) |

> `ts` = typesize；`count` = paramcount（各算子从用户 -b 经 GetCollByteCount 派生）。
> *Broadcast/Reduce 在无流水线树形下上限为 B/log₂n，RCCL 流水线实现下可达 B。

## 三、factor 三类的物理意义

### 1. factor = 2(n−1)/n（仅 AllReduce）
AllReduce = ReduceScatter + AllGather 两阶段串联，环上走 2(n−1) 步。factor 中的"2"补偿两阶段，"(n−1)/n"补偿环转发开销。

### 2. factor = (n−1)/n（环形单阶段类）
适用：AllGather、ReduceScatter、AlltoAll、AlltoAllv、Scatter、Gather。
单阶段环走 n−1 步，每 rank 链路转发 (n−1) 份但"有用数据"是 n 份，factor 抵消这 1 份差异。

### 3. factor = 1（单链路瓶颈类）
适用：Broadcast、Reduce、SendRecv、HyperCube。
- Broadcast/Reduce/SendRecv：root/peer 单链路直接传 M，无复用放大
- HyperCube：baseBw 已按 (n−1) 份实际负载计算，无需再归一化

## 四、统一结论

**所有算子的 busBw 理论上限均为 B（单向链路带宽），与 n、M 无关。**

这是 busBw 指标的设计精妙处：factor 的作用是消去各算法的拓扑放大系数，让 busBw 直接对标硬件链路带宽，从而衡量"链路利用率"。实测 busBw 越接近 B，说明该集合操作越高效。

n 与 M 只影响**能否打满**链路（大消息、高 n 才接近上限），不影响上限本身。

## 五、n=8, M=128MB 手算结果汇总

设 B = 单向链路带宽，M = 128MB（用户 -b 值）。

| 算子 | 每步/每份数据 | 步数/份数 | 总时间 T | algBw | factor | busBw |
|------|-------------|----------|---------|-------|--------|-------|
| AllReduce | 16 MB | 2×7=14 | 224/B | 0.571B | 1.75 | B |
| AllGather | 16 MB | 7 | 112/B | 1.143B | 0.875 | B |
| ReduceScatter | 16 MB | 7 | 112/B | 1.143B | 0.875 | B |
| Broadcast | 128 MB | 1(流水) | 128/B | B | 1 | B |
| Reduce | 128 MB | 1(流水) | 128/B | B | 1 | B |
| AlltoAll | 16 MB | 7 | 112/B | 1.143B | 0.875 | B |
| AlltoAllv | 16 MB | 7 | 112/B | 1.143B | 0.875 | B |
| Scatter | 16 MB | 7 | 112/B | 1.143B | 0.875 | B |
| Gather | 16 MB | 7 | 112/B | 1.143B | 0.875 | B |
| SendRecv | 128 MB | 1 | 128/B | B | 1 | B |
| HyperCube | 16+32+64 MB | 3轮 | 112/B | B | 1 | B |

## 六、算子关系图

```mermaid
graph TD
    SR[SendRecv<br/>点对点原子操作]
    BC[Broadcast 1→all<br/>factor=1]
    RD[Reduce all→1<br/>factor=1]
    AG[AllGather all→all<br/>factor=(n-1)/n]
    RS[ReduceScatter all→all<br/>factor=(n-1)/n]
    AR[AllReduce<br/>factor=2(n-1)/n]
    SC[Scatter 1→all<br/>factor=(n-1)/n]
    GT[Gather all→1<br/>factor=(n-1)/n]
    AA[AlltoAll all→all<br/>factor=(n-1)/n]
    HC[HyperCube<br/>AllGather变体 factor=1]

    SR --> BC
    SR --> RD
    BC -.镜像.-> RD
    RS --> AR
    AG --> AR
    RS -.镜像.-> AG
    BC -.分片.-> SC
    RD -.分片.-> GT
    SC -.镜像.-> GT
    AG -.变体.-> HC
    AG -.全交换.-> AA
```

## 七、典型硬件 busBw 上限参考

| 硬件 | 互连 | 单向 B | busBw 上限 |
|------|------|--------|-----------|
| MI300X | XGMI | ~100 GB/s | ~100 GB/s |
| MI250X | XGMI | ~50 GB/s | ~50 GB/s |
| H100 | NVLink4 | 50 GB/s | 50 GB/s |
| A100 | NVLink3 | 25 GB/s | 25 GB/s |

实测时对比 busBw 与上表，差距即优化空间。

---

*生成时间：2026-07-04 · 基于 rccl-tests 源码（master 分支）*
