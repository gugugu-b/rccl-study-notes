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
- 理解 Tuner 如何动态选择：算法（ring/tree）、channel 数、协议（simple/ll/ll128）
- 阅读 `ext-tuner/example/` 下的示例代码
- 编译并运行一个 Tuner 示例，观察调优效果

### 7.2 性能分析实战（2小时）
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

### 7.3 HIP Graph 集成（1小时）
- 理解 HIP Graph 如何减少 CPU launch 开销
- 使用 rccl-tests 的 `-G` 参数测试 HIP Graph 模式
  ```shell
  ./build/all_reduce_perf -g 8 -b 8 -e 1M -G 10
  ```
- 对比有/无 Graph 时的小消息延迟

### 7.4 了解前沿方向（1小时）
- **MSCCL/MSCCL++**：微软提出的自定义集合算法
  - RCCL 编译选项 `--enable-msccl-kernel`
  - 理解它如何突破 ring/tree 的理论极限
- **rocshmem 集成**：用于 AlltoAll 等 GDA（GPU-Driven Approach）场景
  - 在 RCCL git log 中搜索 `rocshmem` 相关 commit
- **多组并行**：rccl-tests 的 `NCCL_TESTS_SPLIT` 机制
  - 理解如何把 GPU 分组并行执行多个操作

### 7.5 总结与知识体系梳理（1小时）
- 整理 7 天学习笔记，形成个人知识库
- 画一张 RCCL 完整架构图（从 API 到传输层）
- 列出尚未深入的问题清单，作为后续学习方向

---

## 今日产出
- [ ] Tuner 插件运行示例 + 效果对比
- [ ] 性能调优实验报告（参数 × 效果对比表）
- [ ] HIP Graph 性能对比数据
- [ ] RCCL 完整架构图（自绘）
- [ ] 后续学习问题清单

---

## 思考题
1. 在你的硬件环境下，AllReduce 的带宽瓶颈是 xGMI/PCIe 还是网络？如何验证？
2. 调整 `NCCL_NCHANNELS` 到什么值时性能最优？为什么不是越多越好？
3. HIP Graph 对小消息提升明显还是大消息？为什么？
4. MSCCL 相比传统 ring/tree 有什么本质区别？什么场景下有优势？

---

## 参考阅读
- [RCCL Tuner 插件文档](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/using-rccl-tuner-plugin-api.html)
- [RCCL 环境变量文档](https://rocm.docs.amd.com/projects/rccl/en/latest/api-reference/env-variables.html)
- [RCCL 使用技巧](https://rocm.docs.amd.com/projects/rccl/en/latest/how-to/rccl-usage-tips.html)
- RCCL `ext-tuner/example/`、`ext-profiler/` 源码

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
