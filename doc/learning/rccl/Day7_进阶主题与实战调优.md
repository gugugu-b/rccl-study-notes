# Day 7：进阶主题与实战调优

> 所属计划：RCCL 7天深入学习计划（最后一天）

---

## 学习目标
- 掌握 RCCL Tuner 插件机制，能进行自动调优
- 学会使用 Profiler 进行性能分析
- 完成一次端到端的性能调优实践
- 了解 MSCCL、HIP Graph 集成等前沿方向

---

## 任务清单

### 7.1 学习 Tuner 插件（2小时）
- 阅读 [RCCL Tuner 插件 API 文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-rccl-tuner-plugin-api.html)
- 理解 Tuner 如何动态介入选择：算法（Ring / Tree / CollNet）、Channel 通道数、协议（Simple / LL / LL128）
- 阅读 `rccl/ext-tuner/example/` 下的示例代码（如 `plugin.cc`）
- 编译一个 Tuner 插件并配置 `NCCL_TUNER_PLUGIN` 加载，观察实测决策变化

### 7.2 性能分析与环境变量调优实战（2小时）
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

### 7.3 HIP Graph 集成（1小时）
- 理解 HIP Graph（类似 CUDA Graph）如何将通信 Kernel 的 Launch 与 Host 侧排队开销消除
- 使用 rccl-tests 的 `-G` 参数开启 HIP Graph 录制与回放：
  ```shell
  ./all_reduce_perf -g 8 -b 8 -e 1M -G 10
  ```
- 对比有/无 Graph 时小消息（8B ~ 64KB）的端到端延迟变化

### 7.4 了解前沿方向（1小时）
- **MSCCL / MSCCL++**：微软提出的可编程自定义集合通信算法
  - RCCL 编译选项 `--enable-msccl-kernel`
  - 理解其如何针对异构非对称拓扑突破固定 Ring/Tree 的理论上限
- **rocshmem / GPU-Initiated 通信**：用于 AlltoAll 等细粒度通信场景
  - 在 RCCL 源码中关注 `dev_runtime.cc` 与 direct-access 演进
- **多组并行与拓扑切分**：rccl-tests 的 `NCCL_TESTS_SPLIT` 机制
  - 将单机 8 卡切分成两个独立 4 卡进程组并发测试

### 7.5 总结与知识体系梳理（1小时）
- 整理 7 天学习笔记，形成系统性认知
- 绘制 RCCL 完整技术栈链路图（用户 API $\to$ Enqueue $\to$ Graph/Tuning $\to$ Channels $\to$ Transport $\to$ Device Kernel/Proxy）
- 列出未深入的疑难点与后续进阶方向

---

## 今日产出
- [ ] Tuner 插件编译与运行加载实验记录
- [ ] 核心参数调优实验报告（参数 × 带宽/延迟对比表）
- [ ] HIP Graph 小包延迟对比数据
- [ ] RCCL 全流程架构与数据流长图（自绘或文档总结）
- [ ] 后续学习与工程实践清单

---

## 思考题
1. 在你的硬件环境下，AllReduce 的带宽瓶颈是卡间互联（xGMI/HSL/PCIe）还是网络？如何验证？
2. 调整 `NCCL_NCHANNELS` 到什么值时性能最优？为什么不是越多越好？
3. HIP Graph 对小消息提升明显还是大消息？为什么？
4. MSCCL 相比传统 Ring/Tree 有什么本质区别？什么场景下有优势？

---

## 参考阅读
- [RCCL Tuner 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-rccl-tuner-plugin-api.html)
- [RCCL 环境变量文档](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/env-variables.html)
- [RCCL 使用技巧](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/rccl-usage-tips.html)
- 本地源码示例：`rccl/ext-tuner/example/`、`rccl/ext-profiler/`
- 本仓库实战文档：[BW1100 实战调优](../../bw1100/README.md)、[BW150 P2P 调优](../../transport/BW150_8GPU_P2P_tuning.md)

---

## 7天计划完结

恭喜完成 7 天学习！回顾整个路径：

| 天数 | 主题 | 状态 |
|:---:|---|:---:|
| Day 1 | 环境搭建与感性认识 | [ ] |
| Day 2 | 集合操作语义与测试框架 | [ ] |
| Day 3 | 初始化与通信器 | [ ] |
| Day 4 | 拓扑探测与逻辑图构建 | [ ] |
| Day 5 | 核心算法：Ring 与 Tree | [ ] |
| Day 6 | 传输层与 Channel 机制 | [ ] |
| Day 7 | 进阶主题与实战调优 | [ ] |

### 后续深入方向建议
- **框架集成**：研究 PyTorch `torch.distributed` 的 RCCL 后端实现
- **内核优化**：深入 device kernel 的 GPU 架构特定优化（如 MI300 的矩阵核、wave 调度）
- **大规模调优**：在多节点集群上做 AllReduce/AlltoAll 的规模化性能优化
- **贡献开源**：在 [ROCm/rocm-systems](https://github.com/ROCm/rocm-systems) 提交 issue 或 PR
