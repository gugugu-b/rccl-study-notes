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

### 1.1 确认 ROCm 环境（1小时）

- 检查 ROCm 是否已安装：`hipconfig --version`、`/opt/rocm/.info/version`
- 检查 GPU 可见性：`rocm-smi`（应能看到 GPU 设备）
- 确认 HIP 编译器：`which hipcc`、`which amdclang++`
- 记录 ROCm 版本、GPU 型号（如 MI250/MI300）、架构代号（如 gfx90a/gfx942）

### 1.2 编译 rccl-tests（1小时）

```shell
# 在当前项目目录下
make HIP_HOME=/opt/rocm NCCL_HOME=/opt/rocm -j$(nproc)
# 或使用 cmake
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/rocm ..
make -j$(nproc)
```

- 确认 `build/all_reduce_perf` 等可执行文件生成
- 如果编译失败，排查 HIP/RCCL 路径、GPU target 是否匹配

### 1.3 跑通第一个测试（1小时）

```shell
# 单 GPU 基线
./build/all_reduce_perf -b 8 -e 128M -f 2 -g 1

# 多 GPU（如有 2/4/8 卡）
./build/all_reduce_perf -b 8 -e 128M -f 2 -g 8
```

- 观察输出表格的每一列含义
- 重点理解 `algbw`（算法带宽）和 `busbw`（总线带宽）的区别

### 1.4 阅读性能文档（1小时）

- 精读 `doc/PERFORMANCE.md`，理解每种集合操作的 busbw 修正因子推导
- 

---

## 今日产出

- [ ] ROCm 环境信息记录表（版本、GPU、架构）
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

- 当前项目 `README.md` 和 `doc/PERFORMANCE.md`
- [RCCL 官方文档](https://rocm.docs.amd.com/projects/rccl/en/latest/)
- [RCCL GitHub 仓库](https://github.com/ROCm/rccl)（已迁移至 rocm-systems）
