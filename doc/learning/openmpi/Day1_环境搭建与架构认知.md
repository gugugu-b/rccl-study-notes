# Day 1：OpenMPI 环境搭建与架构认知

> 所属计划：OpenMPI 7天深入学习计划
>
> 前置要求：具备 C/C++ 基础、熟悉 Linux 开发环境、理解多进程并发基本概念。

---

## 学习目标

- 理解 MPI（Message Passing Interface）标准与 OpenMPI 开源实现的核心定位
- 掌握 OpenMPI 源码编译与安装（支持 UCX、RoCE/IB、多线程）
- 跑通第一个 MPI 程序并掌握 `mpirun` 的关键进程排布参数
- 理解大模型多机训练（如双机 RCCL 测试）中 OpenMPI 作为启动器（Launcher）的机制

---

## 任务清单

### 1.1 理解 MPI 规范与 OpenMPI 定位（1小时）

- **MPI 是什么**：Message Passing Interface 是高性能计算领域跨节点分布式内存通信的标准规范（由 MPI Forum 制定，经历 MPI-1、MPI-2、MPI-3、MPI-4）。
- **OpenMPI 是什么**：OpenMPI 是 MPI 规范最流行、模块化程度最高的开源实现之一，由工业界（AMD、NVIDIA、IBM、Intel、Mellanox/NVIDIA）和学术界联合维护。
- **与 RCCL/NCCL 的区别**：
  - MPI 面向全功能、通用、异构的进程间通信（涵盖点对点、集合操作、单边通信 RMA、动态进程管理、I/O 等）。
  - RCCL/NCCL 专门针对 GPU/DCU 显存间的高性能集合通信（纯针对 Dense 矩阵梯度同步/张量切片优化，不涉及通用进程启动和复杂业务交互）。
  - 在大模型训练中：OpenMPI 负责节点发现、进程拉起与环境分发；RCCL 负责 GPU 卡间高速数据同步。

### 1.2 OpenMPI 源码获取与生产级编译（2小时）

在多机集群中，生产环境通常要求 OpenMPI 开启 InfiniBand/RoCE（UCX 支持）、多线程并发支持（MPI_THREAD_MULTIPLE）及进程绑定支持（hwloc）。

```shell
# 1. 安装基础依赖
sudo apt-get update && sudo apt-get install -y \
    build-essential gcc g++ gfortran libtool autoconf \
    libnuma-dev libhwloc-dev libevent-dev

# 2. 下载 OpenMPI 源码（推荐 4.1.x 或 5.0.x 稳定分支）
wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.6.tar.gz
tar -zxvf openmpi-4.1.6.tar.gz
cd openmpi-4.1.6

# 3. 配置编译选项（按需启用 UCX 与高性能选项）
./configure --prefix=/opt/openmpi \
    --enable-mpirun-prefix-by-default \
    --enable-shared \
    --enable-static \
    --with-threads=posix \
    --enable-mpi-thread-multiple \
    --with-hwloc=internal \
    --with-libevent=internal \
    --with-ucx=/usr \
    --without-verbs \
    2>&1 | tee config.log

# 4. 编译与安装
make -j$(nproc)
sudo make install

# 5. 配置环境变量（~/.bashrc 或 /etc/profile.d/openmpi.sh）
export PATH=/opt/openmpi/bin:$PATH
export LD_LIBRARY_PATH=/opt/openmpi/lib:$LD_LIBRARY_PATH
export MANPATH=/opt/openmpi/share/man:$MANPATH
```

- 检查验证安装：
  ```shell
  which mpicc
  which mpirun
  ompi_info | head -n 25
  ```

### 1.3 编写与编译第一个 MPI 程序（1.5小时）

编写基础 `hello_mpi.c`：

```c
#include <mpi.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char** argv) {
    // 1. 初始化 MPI 执行环境
    MPI_Init(&argc, &argv);

    // 2. 获取当前通信域中的总进程数（size）与当前进程编号（rank）
    int world_size, world_rank;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    // 3. 获取运行当前进程的节点主机名
    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;
    MPI_Get_processor_name(processor_name, &name_len);

    printf("Hello World from Node %s, Rank %d out of %d processes (PID: %d)\n",
           processor_name, world_rank, world_size, getpid());

    // 4. 清理并退出 MPI 环境
    MPI_Finalize();
    return 0;
}
```

- 编译与单机运行：
  ```shell
  # 编译
  mpicc -O3 hello_mpi.c -o hello_mpi

  # 单机启动 4 个进程
  mpirun -np 4 ./hello_mpi
  ```

### 1.4 掌握 `mpirun` 核心调度与进程排布参数（1.5小时）

`mpirun`（或 `orterun` / `prun`）是 MPI 程序的大脑，掌握其映射（mapping）、分发（ranking）与绑定（binding）机制是性能调优的关键：

```shell
# 1. 多机运行：通过 hostfile 或 -H 指定多节点
# 假设 node1 和 node2 已经配置好 SSH 免密
mpirun -H node1:4,node2:4 ./hello_mpi

# 2. 查看进程与硬件核的物理绑定情况
mpirun -np 4 --report-bindings ./hello_mpi

# 3. 按 NUMA 节点映射并绑定到物理 Core
mpirun -np 8 --map-by numa --bind-to core --report-bindings ./hello_mpi

# 4. 跨节点交错分布（Round-Robin） vs 紧凑分布（Sequential）
# 逐节点轮询分布：
mpirun -H node1:2,node2:2 --map-by node ./hello_mpi
# 逐槽位填满后再分发到下一个节点：
mpirun -H node1:2,node2:2 --map-by slot ./hello_mpi
```

---

## 今日产出

- [ ] OpenMPI 编译安装成功，`ompi_info` 运行无报错
- [ ] 编写并编译 `hello_mpi.c`，输出各 Rank 节点与 PID 信息
- [ ] 实验 `--map-by` 与 `--bind-to` 参数，记录 `--report-bindings` 的核绑定拓扑
- [ ] 梳理单机多进程 vs 跨机多进程 `mpirun` 的启动流程差异笔记

---

## 思考题

1. 在调用 `MPI_Init` 之前和调用 `MPI_Finalize` 之后，能否调用常规 MPI 通信接口？为什么？
2. `MPI_COMM_WORLD` 是什么？能否创建自定义通信域？
3. 当在双机上执行 `mpirun` 时，如果两台机器的 SSH 端口非默认 22 端口（例如本仓库双机测试使用的特定端口），`mpirun` 应当如何配置参数？
   *(提示：查看 `--mca plm_rsh_args "-p <port>"`)*

---

## 参考资料

- [OpenMPI 官方文档站](https://docs.open-mpi.org/en/v5.0.x/)
- [MPI 4.0 官方规范](https://www.mpi-forum.org/docs/mpi-4.0/mpi40-report.pdf)
- 本仓库双机测试脚本：[`run-rccl-perf-suite.sh`](../../../run-rccl-perf-suite.sh)（观察双机模式下 `mpirun` 如何传递环境变量与拉起进程）
