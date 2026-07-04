# RCCL 性能指标详解 · busBw 修正因子推导

> 本文档是集合通信带宽指标的入口索引，详细推导见 [Collective_Communication_Functions/](Collective_Communication_Functions/README.md) 目录。

## 一、核心概念

rccl-tests 对每个集合操作报告两个带宽指标：

- **algBw（算法带宽）** = 数据量 / 耗时，应用视角的吞吐
- **busBw（总线带宽）** = algBw × factor，归一化到单链路利用率

`factor` 是每个算子专属的修正因子，用于把"算法带宽"折算到"等效单链路利用率"，让 busBw 可以直接对标硬件链路带宽 B。

## 二、全算子公式速查

统一场景：n = 8 GPU，M = 128 MB（rccl-tests `-b 134217728`），B = 单向链路带宽。

| 算子 | baseBw（数据量/T） | factor | busBw 上限 | 详细文档 |
|------|-------------------|--------|-----------|---------|
| AllReduce | count×ts | 2(n−1)/n | B | [AllReduce.md](Collective_Communication_Functions/AllReduce.md) |
| AllGather | count×ts×n | (n−1)/n | B | [AllGather.md](Collective_Communication_Functions/AllGather.md) |
| ReduceScatter | count×ts×n | (n−1)/n | B | [ReduceScatter.md](Collective_Communication_Functions/ReduceScatter.md) |
| Broadcast | count×ts | 1 | B* | [Broadcast.md](Collective_Communication_Functions/Broadcast.md) |
| Reduce | count×ts | 1 | B* | [Reduce.md](Collective_Communication_Functions/Reduce.md) |
| AlltoAll | count×ts×n | (n−1)/n | B | [AlltoAll.md](Collective_Communication_Functions/AlltoAll.md) |
| AlltoAllv | count×ts×n | (n−1)/n | B | [AlltoAllv.md](Collective_Communication_Functions/AlltoAllv.md) |
| Scatter | count×ts×n | (n−1)/n | B | [Scatter.md](Collective_Communication_Functions/Scatter.md) |
| Gather | count×ts×n | (n−1)/n | B | [Gather.md](Collective_Communication_Functions/Gather.md) |
| SendRecv | count×ts | 1 | B | [SendRecv.md](Collective_Communication_Functions/SendRecv.md) |
| HyperCube | count×ts×(n−1) | 1 | B | [HyperCube.md](Collective_Communication_Functions/HyperCube.md) |

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

n 与 M 只影响能否打满链路（大消息、高 n 才接近上限），不影响上限本身。实测 busBw 越接近 B，说明该集合操作越高效。

## 五、典型硬件 busBw 上限参考

| 硬件 | 互连 | 单向 B | busBw 上限 |
|------|------|--------|-----------|
| MI300X | XGMI | ~100 GB/s | ~100 GB/s |
| MI250X | XGMI | ~50 GB/s | ~50 GB/s |
| H100 | NVLink4 | 50 GB/s | 50 GB/s |
| A100 | NVLink3 | 25 GB/s | 25 GB/s |

## 六、深入学习

每个算子的完整推导（源码公式、参数含义、算法推导、手算过程、HTML 图解）见：

- **[Collective_Communication_Functions/README.md](Collective_Communication_Functions/README.md)** — 总览索引
- 各算子 `.md` 文件 — 详细推导（含内嵌 HTML 图解）
- 各算子 `_busbw.html` 文件 — 独立可打开的图解卡片

---

*生成时间：2026-07-04 · 基于 rccl-tests 源码（master 分支）*
