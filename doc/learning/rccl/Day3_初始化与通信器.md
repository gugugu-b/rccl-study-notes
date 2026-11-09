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

> 本工作区已在根目录下内置了 `rccl/` 源码子模块，可直接在本地编译，也可以从上游同步。

```shell
# 进入本地 rccl 源码目录
cd rccl
mkdir -p build && cd build

# AMD ROCm 环境编译：
CXX=/opt/rocm/llvm/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/rocm ..
make -j$(nproc)

# 海光 DTK 环境编译：
CXX=/opt/dtk/llvm/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/dtk ..
make -j$(nproc)
```
- 确认 `build/lib/librccl.so` 生成成功
- 用自编译的 RCCL 动态替换系统库验证：`LD_LIBRARY_PATH=$(pwd)/lib:$LD_LIBRARY_PATH ./all_reduce_perf`

### 3.2 阅读初始化流程（2.5小时）
按调用顺序阅读以下文件：

#### API 入口：`rccl/src/init.cc` 中的 `ncclCommInitRank`
- 理解 `ncclCommInitAll`、`ncclCommInitRank`、`ncclCommInitRankConfig` 的关系
- 跟踪 `ncclUniqueId` 的生成（`ncclGetUniqueId`）

#### 通信器结构体：`rccl/src/include/comm.h`
> 注意：公开 API 头文件 `nccl.h.in` 中仅保留不透明类型定义 `typedef struct ncclComm* ncclComm_t;`，真正的内部结构体 `struct ncclComm` 位于 **`rccl/src/include/comm.h`**。
- 重点记录关键字段：
  - 基础属性：`rank`、`nRanks`、`cudaDev`、`busId`
  - 逻辑通道：`channels[MAXCHANNELS]`、`nChannels`
  - 拓扑与算法：`topo`、`ringGraph`、`treeGraph`
  - 内部传输与连接：`peerInfo`、`bootstrap`

#### 初始化主流程：`ncclCommInitRankDev` 调用链
- `bootstrap` 阶段：rank 间互相交换 connection info（socket 通信）
- `initTransportsRank` 阶段：拓扑探测、计算路径、选择传输机制（Day 4 深入）
- `initComm` 阶段：为每个 channel 分配环形/树形通信结构与 ring buffer

### 3.3 理解 Bootstrap 机制（1小时）
- 阅读 `rccl/src/bootstrap.cc`
- 理解 rank 0 如何通过 `ncclGetUniqueId` 创建监听 socket 并生成唯一标识
- 其他 rank 通过 UniqueId 建立连接，并通过 Root 节点组播全局 rank 列表
- 理解 MPI 模式下如何利用 MPI_Bcast 分发 UniqueId

---

## 今日产出
- [ ] 本地 RCCL 源码编译成功，能链接或注入运行 rccl-tests
- [ ] `struct ncclComm`（位于 `rccl/src/include/comm.h`）核心字段注释
- [ ] 初始化流程图（从 `ncclCommInitRank` 到通信器就绪）
- [ ] Bootstrap 机制流程说明（1页）

---

## 思考题
1. `ncclUniqueId` 是如何保证跨节点唯一且可传递的？
2. 为什么初始化要区分 bootstrap、initTransports、initComm 三个阶段？
3. `ncclCommInitRank` 中的 `comm->rank` 和 MPI 的 rank 是什么关系？

---

## 参考阅读
- [init.cc](../../../rccl/src/init.cc)、[bootstrap.cc](../../../rccl/src/bootstrap.cc)、[comm.h](../../../rccl/src/include/comm.h)
- [从调用NCCL到深入NCCL源码](https://blog.csdn.net/Chenzhinan1219/article/details/142878010)（NCCL 与 RCCL 架构相通）
