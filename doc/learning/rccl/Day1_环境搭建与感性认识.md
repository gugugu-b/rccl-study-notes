# Day 1：环境搭建与感性认识

> 所属计划：RCCL 7天深入学习计划
>
> 前置要求：具备 C/C++ 基础、了解 GPU 编程（HIP/CUDA）、熟悉 Linux 开发环境

---

## 学习目标

- 搭建可运行的 ROCm + RCCL + rccl-tests 环境
- 跑通第一个集合通信测试，理解输出指标
- 建立"集合通信到底在干什么"的直觉

---

## 任务清单

### 1.1 确认加速卡与编译环境（1小时）

根据你使用的硬件平台（AMD ROCm 或 海光 DCU / DTK），执行对应检查：

| 检查项 | AMD ROCm 平台 | 海光 Hygon DCU / DTK 平台 |
|---|---|---|
| 安装路径 | `/opt/rocm` | `/opt/dtk` |
| 版本查询 | `hipconfig --version`、`/opt/rocm/.info/version` | `hipconfig --version`、`/opt/dtk/.dtk_version` |
| 设备拓扑与可见性 | `rocm-smi` | `hy-smi` |
| 编译器 | `which hipcc`、`which amdclang++` | `which hipcc`、`which clang++` |
| 典型硬件架构 | MI250X (gfx90a) / MI300X (gfx942) | BW1100 / BW150 / K100_AI (gfx906/gfx928) |

- 记录当前环境的 ROCm/DTK 版本、GPU/DCU 型号与架构代号。

### 1.2 编译 rccl-tests（1小时）

rccl-tests 位于仓库的 `rccl-tests/` 子目录下：

```shell
# 进入 rccl-tests 目录
cd rccl-tests

# 方式一：Makefile 直接编译（指定 HIP 与 NCCL/RCCL 路径）
# AMD ROCm 环境：
make HIP_HOME=/opt/rocm NCCL_HOME=/opt/rocm -j$(nproc)
# 海光 DTK 环境：
make HIP_HOME=/opt/dtk NCCL_HOME=/opt/dtk -j$(nproc)

# 方式二：CMake 编译
mkdir -p build && cd build
# AMD ROCm：
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/rocm ..
# 海光 DTK：
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/dtk ..
make -j$(nproc)
```

- 确认 `build/all_reduce_perf` 等可执行文件已生成
- 如果编译失败，排查 HIP/RCCL 路径、GPU target 是否匹配

### 1.3 跑通第一个测试（1小时）

```shell
# 在 rccl-tests/build 目录下执行
# 单 GPU 基线
./all_reduce_perf -b 8 -e 128M -f 2 -g 1

# 多卡基线（如有 2/4/8 卡）
./all_reduce_perf -b 8 -e 128M -f 2 -g 8
```

- 观察输出表格的每一列含义
- 重点理解 `algbw`（算法带宽）和 `busbw`（总线带宽）的区别

### 1.4 阅读性能文档（1小时）

- 精读 [带宽指标说明](PERFORMANCE.md)，理解每种集合操作的 busbw 修正因子推导
- 自己用公式手算一次：8 GPU、128MB AllReduce 的理论 busbw 上限是多少

---

## 今日产出

- [ ] 加速卡环境信息记录表（ROCm/DTK 版本、GPU/DCU 型号、架构）
- [ ] rccl-tests 编译成功并能运行
- [ ] 一份 all_reduce_perf 的输出截图 + 自己对各列的注释
- [ ] 手算的带宽理论值

---

## 思考题

1. 为什么 `busbw` 比 `algbw` 更适合衡量集合通信的效率？
2. 当 GPU 数从 1 增加到 8 时，`algbw` 如何变化？`busbw` 呢？为什么？
3. 小消息（8B）和大消息（128MB）的性能瓶颈分别是什么？

---

## 参考资料

- [rccl-tests 使用说明](../../../rccl-tests/README.md)和[带宽指标说明](PERFORMANCE.md)
- [RCCL 官方文档](https://rocm.docs.amd.com/projects/rccl/en/latest/)
- [RCCL GitHub 仓库](https://github.com/ROCm/rccl)（已迁移至 rocm-systems）
