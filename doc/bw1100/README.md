# BW1100 8 卡 RCCL 实测与复现

| 要做的事 | 文档 | 数据口径 |
| --- | --- | --- |
| 比较 DTK 26.04.1 镜像和 DTK 26.10 | [同机 A/B](DTK_26.04.1_vs_26.10_同机对照.md) | 同一宿主驱动、同一测试二进制和参数，FP32 三轮中位数 |
| 取回实测使用的 RCCL Git 版本 | [RCCL 源码 ZIP 备份](archives/README.md) | 按实测提交的完整 SHA 固定版本 |
| 在 BW1100 安装 DTK 26.10 并跑通测试 | [安装与测试](DTK_26.10_BW1100_RCCL_安装与测试.md) | 驱动和工具链安装流程、冒烟测试和默认参数示例 |
| 用 RoCE 或 InfiniBand 测双机 RCCL | [双机 RoCE 与 IB 测试](双机_RCCL_RoCE_与_IB_测试.md) | 单口 RDMA 检查、双机 2 rank 冒烟、16 rank 性能测试 |
| 查算子公式、图解、历史数值和调优结果 | [各算子带宽说明](collectives/README.md) | 历史截图、默认参数和逐算子调优数据分别记录 |
| 用指定拓扑复跑调优配置 | 仓库旁的 `rccl-private/doc/bw1100/single_node_topo/` | 固定拓扑文件及调优参数，随包长检查 `#wrong` |

横向比较 DTK 版本时，使用同机 A/B 的同包长数据。需要复跑调优结果时，对照复现脚本及其校验范围。
