# rccl-study-notes

RCCL（Radeon Collective Communication Library）学习笔记，记录 7 天学习路径与性能调优要点。

## 目录结构

```
rccl-study-notes/
├── doc/                            # 学习笔记（核心内容）
│   ├── RCCL_7天学习计划.md
│   ├── Day1_环境搭建与感性认识.md
│   ├── Day2_集合操作语义与测试框架.md
│   ├── Day3_初始化与通信器.md
│   ├── Day4_拓扑探测与逻辑图构建.md
│   ├── Day5_核心算法Ring与Tree.md
│   ├── Day6_传输层与Channel机制.md
│   ├── Day7_进阶主题与实战调优.md
│   ├── PERFORMANCE.md
│   └── Collective_Communication_Functions/
└── rccl-tests/                     # 上游 ROCm/rccl-tests（git submodule）
```

## 学习路径建议

按 `doc/RCCL_7天学习计划.md` 的顺序，从 Day1 到 Day7 依次阅读，配合 `PERFORMANCE.md` 中的调优要点进行实践。

`Collective_Communication_Functions/` 下收录了各集合通信算子的语义说明与性能数据（AllReduce、Broadcast、AllGather、ReduceScatter、AlltoAll、SendRecv 等），可作为日常查阅的速查手册。

## License

MIT License。