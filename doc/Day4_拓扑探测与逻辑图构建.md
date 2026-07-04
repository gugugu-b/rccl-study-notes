# Day 4：拓扑探测与逻辑图构建

> 所属计划：RCCL 7天深入学习计划

---

## 学习目标
- 理解 RCCL 如何探测系统物理拓扑（PCIe/xGMI/NUMA/网络）
- 理解如何从物理拓扑构建逻辑通信图（ring/tree）
- 掌握 `NCCL_DEBUG=GRAPH` 输出的解读

---

## 任务清单

### 4.1 阅读拓扑探测代码（2小时）
- `src/topo.cc`（或 `src/graph/topo.cc`）：系统拓扑探测
  - 理解如何检测 GPU 间连接类型：P2P（xGMI/PCIe）、共享内存、网络
  - 理解 NUMA 距离、PCI 距离如何量化
  - 重点：AMD xGMI 与 NVIDIA NVLink 的差异（在代码中找 `xgmi` 或 `gmi` 相关逻辑）

- `src/graph/` 目录：图构建模块
  - `graph.cc`：图的节点和边的数据结构
  - `paths.cc`：路径计算（GPU 间最优路径）

### 4.2 阅读 Ring/Tree 构建算法（2小时）
- `src/graph/ring.cc`：ring 逻辑拓扑构建
  - 理解如何搜索一个使总带宽最大的 ring 排列
  - 理解多 ring（双环、四环）的作用

- `src/graph/tree.cc`：tree 逻辑拓扑构建
  - 理解节点内 chain + 节点间 tree 的组合策略
  - 理解 tree 的 parent/child 关系如何决定数据流

### 4.3 实战：解读 DEBUG 输出（1.5小时）
```shell
NCCL_DEBUG=GRAPH ./build/all_reduce_perf -g 8 -b 1M -e 1M -n 1
```
- 找到输出的拓扑信息：物理拓扑图、构建的 ring/tree、channel 数量
- 对照源码理解每一行日志的含义
- 尝试不同 GPU 数（1/2/4/8），观察拓扑变化

### 4.4 对比 xGMI vs PCIe 场景（0.5小时）
- 如果环境有 xGMI 互联（MI250/MI300），对比有/无 xGMI 时的拓扑差异
- 在 `NCCL_DEBUG=GRAPH` 输出中找到 xGMI 连接的标记

---

## 今日产出
- [ ] 系统物理拓扑图（基于 `rocm-smi` 和 `NCCL_DEBUG=GRAPH`）
- [ ] Ring 构建算法的步骤说明
- [ ] Tree 构建算法的步骤说明
- [ ] 一份 `NCCL_DEBUG=GRAPH` 完整输出的注释版

---

## 思考题
1. 为什么 RCCL 要构建多 ring？单 ring 的带宽瓶颈在哪？
2. 节点内 ring + 节点间 ring 的组合，与节点内 chain + 节点间 tree 的组合，各适用于什么场景？
3. xGMI 比 PCIe 快多少？在拓扑图中如何体现？

---

## 参考阅读
- RCCL 源码 `src/topo.cc`、`src/graph/ring.cc`、`src/graph/tree.cc`
- [理解NCCL的Tree](https://blog.csdn.net/shanleo1986/article/details/137014604)
- [NCCL 拓扑与算法分析](https://blog.csdn.net/rjc_lihui/article/details/150060380)
