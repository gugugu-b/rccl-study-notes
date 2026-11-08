# Day 3：RCCL 源码入门：初始化与通信器

> 所属计划：RCCL 7天深入学习计划
>
> 从今天开始进入 RCCL 源码本身。源码仓库已迁移至 [ROCm/rocm-systems](https://github.com/ROCm/rocm-systems)，旧的 `ROCm/rccl` 仓库 `develop_deprecated` 分支仍可作为参考。

---

## 学习目标
- 获取并编译 RCCL 源码
- 理解通信器（`ncclComm_t`）的创建全流程
- 搞清 rank 分配、UniqueId 生成、进程组建立的机制

---

## 任务清单

### 3.1 获取与编译 RCCL 源码（1.5小时）
```shell
git clone --recursive https://github.com/ROCm/rocm-systems.git
cd rocm-systems/rccl  # 或对应子目录
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```
- 如果新仓库结构不同，参考 `ROCm/rccl` 的 `develop_deprecated` 分支
- 确认 `librccl.so` 生成成功
- 用自编译的 RCCL 重新链接 rccl-tests，验证可运行

### 3.2 阅读初始化流程（2.5小时）
按调用顺序阅读以下文件：

#### API 入口：`src/init.cc` 中的 `ncclCommInitRank`
- 理解 `ncclCommInitAll`、`ncclCommInitRank`、`ncclCommInitRankConfig` 的关系
- 跟踪 `ncclUniqueId` 的生成（`ncclGetUniqueId`）

#### 通信器结构体：`src/nccl.h` 中的 `ncclComm` 定义
- 找到 `struct ncclComm` 的完整定义（可能在 `src/nccl.h` 或内部头文件）
- 记录关键字段：rank、nRanks、channels、transports、graph 等

#### 初始化主流程：`ncclCommInitRank` 内部调用链
- `bootstrap` 阶段：rank 间如何互相发现（socket/multicast）
- `initTransports` 阶段：拓扑探测与传输建立（今天先了解入口，Day 4 深入）
- `initComm` 阶段：channel 与 communicator 的最终建立

### 3.3 理解 Bootstrap 机制（1小时）
- 阅读 `src/bootstrap.cc`（或对应文件）
- 理解 rank 0 如何通过 UniqueId 创建监听，其他 rank 如何连接
- 理解 MPI 模式下 bootstrap 的差异

---

## 今日产出
- [ ] RCCL 源码编译成功，能替换系统库运行 rccl-tests
- [ ] `ncclComm` 结构体字段注释文档
- [ ] 初始化流程图（从 `ncclCommInitRank` 到通信器就绪）
- [ ] Bootstrap 机制说明（1页）

---

## 思考题
1. `ncclUniqueId` 是如何保证跨节点唯一且可传递的？
2. 为什么初始化要区分 bootstrap、initTransports、initComm 三个阶段？
3. `ncclCommInitRank` 中的 `comm->rank` 和 MPI 的 rank 是什么关系？

---

## 参考阅读
- RCCL 源码 `src/init.cc`、`src/bootstrap.cc`
- [从调用NCCL到深入NCCL源码](https://blog.csdn.net/Chenzhinan1219/article/details/142878010)（NCCL 与 RCCL 架构相通）
