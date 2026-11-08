# BW1100 实测 RCCL 源码备份

这两份 ZIP 来自海光官方 `HYGON-AI/rccl-dtk` 仓库，按[同机对照日志中的版本](../DTK_26.04.1_vs_26.10_同机对照.md)固定到完整 Git 提交。每份 ZIP 的注释记录了对应的提交 SHA。

| 测试环境 | RCCL 版本 | 本地源码 ZIP | Git 提交 |
| --- | --- | --- | --- |
| DTK 26.04.1 镜像 | 2.22.3-HEAD | [rccl-dtk-2.22.3-e6f150a.zip](rccl-dtk-2.22.3-e6f150a.zip) | [e6f150adffae44d3bf8cdf37c319c5deac3c1eea](https://github.com/HYGON-AI/rccl-dtk/commit/e6f150adffae44d3bf8cdf37c319c5deac3c1eea) |
| DTK 26.10 | 2.27.7-HEAD | [rccl-dtk-2.27.7-3b793e3.zip](rccl-dtk-2.27.7-3b793e3.zip) | [3b793e364a7d7c2d54c02c659cb028a2869e9924](https://github.com/HYGON-AI/rccl-dtk/commit/3b793e364a7d7c2d54c02c659cb028a2869e9924) |

## ZIP SHA256

```text
2dddfbdacb7b09112a113d50505bca68840940d209fa9c5dddd1546faa32f097  rccl-dtk-2.22.3-e6f150a.zip
15709d2a203d21e37f4fd01935a85c7b098de185f24501be8611c74bdd857063  rccl-dtk-2.27.7-3b793e3.zip
```

## Git 子模块

ZIP 保存主仓库的源码快照。需要构建时，按包内 `.gitmodules` 的仓库地址和以下提交另行获取子模块源码。

| RCCL 提交 | 子模块路径 | 子模块提交 |
| --- | --- | --- |
| `e6f150a` | `ext-src/json` | `9cca280a4d0ccf0c08f47a99aa71d1b0e52f8d03` |
| `e6f150a` | `ext-src/mscclpp` | `4ee15b7ad085daaf74349d4c49c9b8480d28f0dc` |
| `3b793e3` | `tools/googletest` | `71815bbf7de6e10c11821d654a2fae2cf42de0f7` |
| `3b793e3` | `tools/rccl-rdma-sharp-plugins-508-rccl-rdma-sharp-plugins-v8` | `9d7e157e10def39707e97f01785bc733b6b903e0` |
