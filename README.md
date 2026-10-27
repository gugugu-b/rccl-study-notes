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
├── rccl-tests/                     # 上游 ROCm/rccl-tests（git submodule）
└── test-rccl.sh                    # RCCL 性能测试脚本（单机 / 双机 mpirun）
```

## 学习路径建议

按 `doc/RCCL_7天学习计划.md` 的顺序，从 Day1 到 Day7 依次阅读，配合 `PERFORMANCE.md` 中的调优要点进行实践。

`Collective_Communication_Functions/` 下收录了各集合通信算子的语义说明与性能数据（AllReduce、Broadcast、AllGather、ReduceScatter、AlltoAll、SendRecv 等），可作为日常查阅的速查手册。

## 测试脚本

`test-rccl.sh` 用于批量跑 `rccl-tests` 构建产物中的 `*_perf` 性能程序，支持单机与双机（mpirun）两种模式。

```bash
./test-rccl.sh            # 默认单机测试（single_test）
./test-rccl.sh double_test  # 双机测试（mpirun）
```

脚本头部可调参数：

| 变量 | 说明 |
| --- | --- |
| `BUILD_DIR` | `rccl-tests` 构建目录，默认 `/workspace/rccl-tests-master/build` |
| `LOG_DIR` | 日志输出目录，默认 `logs/`（分 `single_test/`、`double_test/`） |
| `CARD_NUMS` | 参与测试的卡数列表，默认 `(8)` |

双机模式下使用 `mpirun` 拉起两台机器各 `CARD_NUMS` 个进程，并带上 IB 相关环境变量（`NCCL_IB_HCA`、`NCCL_IB_GID_INDEX`、`NCCL_NET_GDR_READ` 等），节点名、网卡名与 SSH 端口需按实际环境修改脚本中的 `mpirun` 参数。

## License

MIT License。