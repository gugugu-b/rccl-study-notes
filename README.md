# RCCL 工作区

从[文档导航](doc/README.md)查找 RCCL 学习笔记、海光 DCU 实测摘要和测试源码包。

## 常用入口

- [BW1100 8 卡实测与复现](doc/bw1100/README.md)汇集 DTK 安装、同机版本对比、各算子带宽和调优脚本。
- [RCCL 7 天学习计划](doc/learning/RCCL_7天学习计划.md)串联环境搭建、源码阅读、拓扑和调优。
- 厂商原件、实测原始数据和拓扑复现套件保存在仓库旁的 `rccl-private` 目录。

`rccl/` 是本地 RCCL 源码参考副本。[rccl-tests](rccl-tests/README.md) 是本仓库的测试套件子模块。

## 测试脚本

[run-rccl-perf-suite.sh](run-rccl-perf-suite.sh)用于批量运行 `rccl-tests` 构建产物中的 `*_perf` 性能程序，支持单机和双机 MPI 两种模式。

```bash
./run-rccl-perf-suite.sh              # 默认单机测试（single_test）
./run-rccl-perf-suite.sh double_test  # 双机测试（mpirun）
```

脚本头部可调参数（前三个支持同名环境变量覆盖）：

| 变量 | 说明 |
| --- | --- |
| `BUILD_DIR` | `rccl-tests` 构建目录，默认 `/workspace/rccl-tests-master/build` |
| `LOG_DIR` | 日志输出目录，默认 `logs/`（分 `single_test/`、`double_test/`） |
| `CSV_FILE` | 统计汇总 CSV，默认 `rccl_perf_summary.csv` |
| `CARD_NUMS` | 参与测试的卡数列表，默认 `(8)` |

每轮测试结束会把结果追加写入 CSV，列为 `算子类型,测试模式,卡数,数据包大小,In-Place_BusBW(GB/s),DTK版本`：

- `In-Place_BusBW` 取自 rccl-tests 输出表格中**最后一个数据包**（即 `-e` 指定上限）的 in-place busbw 列。该表格每行 13 列（`size/count/type/redop/root` + out-of-place 与 in-place 各 4 列），脚本取第 12 列。DTK 版本读取 `/opt/dtk/.dtk_version`。
- 通用脚本的单机模式跳过 `hypercube_perf`，双机模式包含它。BW1100 单机复现套件通过 `-t 8 -g 1` 运行该用例。
- `tee` 采用覆盖写（而非追加），避免上一次的旧日志被再次解析进 CSV。

双机模式下使用 `mpirun` 拉起两台机器各 `CARD_NUMS` 个进程，并带上 IB 相关环境变量（`NCCL_IB_HCA`、`NCCL_IB_GID_INDEX`、`NCCL_NET_GDR_READ` 等），节点名、网卡名与 SSH 端口需按实际环境修改脚本中的 `mpirun` 参数。

## License

MIT License。
