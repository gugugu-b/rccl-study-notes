# BW1100 单机 8 卡 DTK 26.04.1 与 26.10 对照

2026-11-08 在同一台 8 卡 BW1100 上对照。A 组使用 `sglang:0.5.18-ubuntu22.04-dtk26041-py3.10` 镜像自带的 DTK。B 组在同一镜像底座挂载宿主机的 DTK 26.10。两边都挂载宿主机 `/opt/hyhal`，驱动为 `6.4.2-V2.1.0`，卡序一致，测试前后均有 56 条 HSL 链路处于 up 状态。

| 组别 | DTK 自报版本 | 实际加载的 RCCL |
| --- | --- | --- |
| A | `DTK-26.04-blas-nightly-1021` | `2.22.3-HEAD`（`e6f150a`） |
| B | `DTK-26.10-release` | `2.27.7-HEAD`（`3b793e3`） |

两边使用同一份 `rccl-tests` 二进制（`40b1b179`）及 FP32 参数 `-b 1M -e 1G -f 2 -d float -g 8`。HyperCube 使用 `-t 8 -g 1`，两边都设置 `RCCL_FORCE_DETECT_TOPO=1`。每组跑三轮。两边的 `libhsa-runtime64.so.1` 哈希相同，`libgalaxyhip.so.5` 和 `librccl.so` 哈希不同。差值反映两套用户态组合的表现。

## 1 GiB out-of-place BusBW

| 算子 | A（GB/s） | B（GB/s） | 变化 |
| --- | ---: | ---: | ---: |
| AllToAll | 117.98 | 120.52 | +2.15% |
| Gather | 160.32 | 162.18 | +1.16% |
| Scatter | 159.40 | 161.13 | +1.09% |
| AllToAllv | 96.32 | 97.10 | +0.81% |
| ReduceScatter | 127.71 | 127.93 | +0.17% |
| Broadcast | 131.23 | 131.25 | +0.02% |
| AllReduce | 131.13 | 131.01 | −0.09% |
| Reduce | 131.03 | 130.91 | −0.09% |
| HyperCube | 114.24 | 113.96 | −0.25% |
| AllGather | 129.36 | 128.91 | −0.35% |
| SendRecv | 128.71 | 127.73 | −0.76% |

在 1 MiB，B 组的 out-of-place BusBW 有 10 项低于 A 组。AllReduce 从 22.48 降到 17.15 GB/s，耗时从 81.62 增到 107.00 µs。

所有 1 GiB out-of-place 样本均通过正确性校验。A 组第二轮在 8 MiB ReduceScatter out-of-place 报 1 个错误。随后两组在该包长单独进行三次校验，均通过。

全包长中位数、命令、探测和逐轮日志位于测试机 `/data4/dtk-ab-26041-2610.nADTMr/`，汇总文件为 `comparison.csv`。
