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
- `rccl/src/graph/topo.cc` 与 `topo.h`：系统物理拓扑探测
  - 理解如何检测 GPU 间连接类型：P2P（xGMI / HSL / PCIe）、共享内存（SHM）、网卡（NET/IB/RoCE）
  - 理解 NUMA 距离、PCIe 交换机（PLX）层级与距离量化
  - 重点：AMD xGMI / 海光 HSL（Hygon StarLink）与 PCIe 的拓扑差异（在代码中搜索 `xgmi`、`hsl`、`pci` 相关探测逻辑）

- `rccl/src/graph/` 核心图模块：
  - `topo.h`：拓扑节点系统（`ncclTopoSystem`、`ncclTopoNode`、`ncclTopoLink`）
  - `paths.cc`：路径计算与 GPU 间距离矩阵更新（`ncclTopoComputePaths`）
  - `search.cc`：从拓扑图搜索最优通道配置（`ncclTopoSearch`）

### 4.2 阅读 Ring/Tree 构建算法（2小时）
- `rccl/src/graph/rings.cc`：Ring 逻辑拓扑构建
  - 理解如何搜索一个使总带宽最大的 Ring 排列（`ncclBuildRings`）
  - 理解多环（双环、四环、八环）通道复用的作用
  - 理解交叉环与同心环的设计

- `rccl/src/graph/trees.cc`：Tree 逻辑拓扑构建
  - 理解节点内 chain + 节点间 tree 的分层策略（`ncclBuildTree`）
  - 理解 Tree 的 parent / child 拓扑结构如何决定数据流向

- `rccl/src/graph/connect.cc` 与 `tuning.cc`：
  - 连接 channel 上的各个 rank 并为不同消息尺寸设定算法选优阈值

### 4.3 实战：解读 DEBUG 输出（1.5小时）
在 `rccl-tests` 编译目录下执行：
```shell
NCCL_DEBUG=GRAPH ./all_reduce_perf -g 8 -b 1M -e 1M -n 1
```
- 找到输出的拓扑信息：物理拓扑图（XML 或矩阵）、构建的 ring/tree 序列、channel 数量与带宽折算
- 对照源码理解每一行日志含义（如 `Ring 00 : 0 -> 1 -> 2 -> ...`）
- 尝试不同 GPU 数（1/2/4/8），观察拓扑与 Channel 构建的变化

### 4.4 对比高速互联 vs PCIe 场景（0.5小时）
- 如果环境具备高速互联（如 AMD xGMI、海光 HSL 互联的 BW1100），对比跨 NUMA / 纯 PCIe 机器（如 BW150）的拓扑差异
- 在 `NCCL_DEBUG=GRAPH` 输出中确认高速链路类型（`P2P/XGMI`、`P2P/HSL` 或 `P2P/PCI`）

---

## 今日产出
- [ ] 系统物理拓扑图（基于 `hy-smi` / `rocm-smi` 和 `NCCL_DEBUG=GRAPH`）
- [ ] Ring 构建算法流程说明
- [ ] Tree 构建算法流程说明
- [ ] 一份 `NCCL_DEBUG=GRAPH` 完整输出的逐行注释

---

## 思考题
1. 为什么 RCCL 要构建多 Ring？单 Ring 的带宽瓶颈在哪？
2. 节点内 Ring + 节点间 Ring 的组合，与节点内 Chain + 节点间 Tree 的组合，各适用于什么场景？
3. 高速卡间互联（xGMI / HSL）比 PCIe 快多少？在拓扑图中如何体现？

---

## 参考阅读
- [topo.cc](../../../rccl/src/graph/topo.cc)、[rings.cc](../../../rccl/src/graph/rings.cc)、[trees.cc](../../../rccl/src/graph/trees.cc)、[search.cc](../../../rccl/src/graph/search.cc)
- [理解NCCL的Tree](https://blog.csdn.net/shanleo1986/article/details/137014604)
- [NCCL 拓扑与算法分析](https://blog.csdn.net/rjc_lihui/article/details/150060380)
