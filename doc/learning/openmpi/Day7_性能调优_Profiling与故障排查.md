# Day 7：性能调优、Profiling 与大规模故障排查

> 所属计划：OpenMPI 7天深入学习计划（最后一天）
>
> 核心目标：掌握大规模分布式生产环境下的进程亲和性调优、OSU 基准测试、Profiling 追踪工具与典型故障定位策略。

---

## 学习目标

- 彻底掌握 CPU 核绑定、NUMA 节点与网卡/GPU 物理亲和性调优
- 熟练使用超算工业界基准测试套件 **OSU Micro-Benchmarks（OMB）**
- 掌握 PMPI 分析接口与轻量级 Tracing 分析工具的使用
- 掌握大规模集群生产常见故障排查（Rank 挂起卡死、RDMA Retry 超时、SSH 环境变量丢失）

---

## 任务清单

### 7.1 核心调优一：CPU/NUMA/GPU/网卡 硬件四位一体亲和性（2小时）

在现代双路或四路服务器架构中，跨 NUMA 访问会导致严重的跨总线带宽减半与延迟倍增：

```
[Socket 0 (NUMA 0)] ════════ QPI / UPI / xGMI 跨片总线 ════════ [Socket 1 (NUMA 1)]
     ├── CPU Core 0~31                                               ├── CPU Core 32~63
     ├── PCIe Root Complex 0                                         ├── PCIe Root Complex 1
     │    ├── GPU 0 ~ GPU 3                                          │    ├── GPU 4 ~ GPU 7
     │    └── 网卡 mlx5_0 (RoCE/IB)                                  │    └── 网卡 mlx5_1 (RoCE/IB)
```

- **黄金亲和性法则**：
  Rank $i$ 的 CPU 核心必须绑定在与其操作的 GPU 及物理网卡属于**同一 NUMA 节点**的物理 Core 上！

- **`mpirun` 高级亲和性调优模板**：
  ```shell
  # 推荐模板：按 NUMA 映射，按 Core 绑定，打印绑定拓扑
  mpirun -np 8 \
      --map-by numa \
      --bind-to core \
      --report-bindings \
      ./my_mpi_app

  # 如果运行 GPU/DCU 任务，精确将 Rank 0~3 绑到 Socket 0，Rank 4~7 绑到 Socket 1
  mpirun -np 8 \
      --map-by ppr:4:numa \
      --bind-to core \
      --report-bindings \
      ./gpu_ping_pong
  ```

### 7.2 核心调优二：编译与运行 OSU Micro-Benchmarks（OMB）（1.5小时）

OMB 是全球超级计算机与 AI 集群验证 MPI 与网络性能的通用黄金标准：

```shell
# 1. 下载 OMB 源码
wget https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-7.3.tar.gz
tar -zxvf osu-micro-benchmarks-7.3.tar.gz
cd osu-micro-benchmarks-7.3

# 2. 编译（如需 GPU-Aware 测试需带对应标志）
./configure CC=mpicc CXX=mpicxx --prefix=/opt/omb
make -j$(nproc)
sudo make install

# 3. 运行基础点对点延迟与带宽测试
cd /opt/omb/libexec/osu-micro-benchmarks/mpi/pt2pt
# 单机 2 进程延迟
mpirun -np 2 ./osu_latency
# 双机跨网络带宽
mpirun -H node1:1,node2:1 ./osu_bw

# 4. 运行集合通信测试
cd /opt/omb/libexec/osu-micro-benchmarks/mpi/collective
mpirun -np 8 ./osu_allreduce
```

### 7.3 PMPI 性能分析剖析（Profiling Interface）（1小时）

MPI 规范原生内置了 **PMPI 机制**（Profiling MPI）。所有 `MPI_*` 函数底层都会弱符号链接到 `PMPI_*`。用户可以在不修改原有业务代码的情况下，编写一个拦截动态库记录每个 API 的调用耗时：

```c
// 简单的 PMPI 拦截示例：记录 MPI_Allreduce 调用次数与耗时
#include <mpi.h>
#include <stdio.h>

int MPI_Allreduce(const void *sendbuf, void *recvbuf, int count,
                  MPI_Datatype datatype, MPI_Op op, MPI_Comm comm) {
    double t0 = MPI_Wtime();

    // 调用底层真正的 PMPI 实现
    int ret = PMPI_Allreduce(sendbuf, recvbuf, count, datatype, op, comm);

    double t1 = MPI_Wtime();
    int rank;
    PMPI_Comm_rank(comm, &rank);
    if (rank == 0) {
        printf("[PMPI-Trace] Allreduce count=%d took %.3f ms\n", count, (t1 - t0) * 1000.0);
    }
    return ret;
}
```

- 编译成动态库并用 `LD_PRELOAD` 无侵入注入任何现存二进制！

### 7.4 生产级经典故障排查锦囊（1.5小时）

#### 故障 1：跨机 `mpirun` 卡住，无任何日志输出
- **根本原因**：
  1. 节点间非标准 SSH 端口未显式配置。
  2. 防火墙拦截了 OpenMPI 的带外通信端口（ORTE OOB 默认随机分配 TCP 高位端口）。
- **解决方案**：
  ```shell
  # 显式指定 SSH 端口（如 2222）
  mpirun --mca plm_rsh_args "-p 2222" -H node1,node2 ...

  # 限定带外通信端口范围以便防火墙放行
  mpirun --mca oob_tcp_static_ipv4_ports 15000-15050 ...
  ```

#### 故障 2：网络运行中报错 `IBV_WC_RETRY_EXC_ERR`
- **现象**：`Transport Retry Counter Exceeded`，通信中止。
- **根本原因**：网络物理丢包导致 RDMA 可靠连接（RC）在达到最大重传计数后放弃。
- **解决方案**：
  1. 检查交换机 PFC（基于优先级的流控）与 ECN 是否生效。
  2. 检查两端网卡 MTU 是否一致（如 Jumbo Frame 9000 vs 1500）。
  3. 增加 UCX 重传超时时间：`-x UCX_IB_TRAFFIC_CLASS=106 -x UCX_IB_TIMEOUT=2000000.0`。

#### 故障 3：大模型双机训练环境变量在远端丢失
- **现象**：本地设置了 `NCCL_DEBUG=INFO` 或 `ROCR_VISIBLE_DEVICES`，但远端第二台机器未生效。
- **解决方案**：必须在 `mpirun` 中通过 `-x` 参数显式传递：
  ```shell
  mpirun -x NCCL_DEBUG=INFO -x NCCL_IB_HCA=mlx5_0:1 -x LD_LIBRARY_PATH ...
  ```
  *(注：本仓库根目录的 `run-rccl-perf-suite.sh` 脚本便是采用此标准模式传递环境参数)*

---

## 今日产出

- [ ] 掌握 `--report-bindings` 与 `--map-by numa` 调优技巧并消除跨 Socket 内存抖动
- [ ] 编译并成功运行 OSU Micro-Benchmarks，产出完整的延迟/带宽基准测试数据
- [ ] 理解 PMPI 拦截注入机制与无侵入性能追踪
- [ ] 总结并归纳生产环境死锁、超时与网络配置错误排查手册

---

## 思考题

1. 什么是 NUMA 远程内存访问（Remote Access）？为什么用 `numactl -H` 看到的跨 Node 访问延迟会比本地 Node 高很多？
2. 在跨机多节点测试中，如果某些 Rank 发生崩溃，整个 MPI 作业默认会立刻终止退出还是永久卡死？OpenMPI 是通过什么心跳机制检测故障节点的？
3. 对比单机多进程共享内存、双机以太网 TCP、双机 RoCEv2 与双机原生 InfiniBand，各层级的 8 字节延迟（Ping-Pong Latency）量级大概是多少？

---

## 参考阅读

- [OSU Micro-Benchmarks 官方使用指南](https://mvapich.cse.ohio-state.edu/benchmarks/)
- [OpenMPI 故障排障官方 FAQ](https://www.open-mpi.org/faq/?category=running)
- 本仓库实战脚本：[`run-rccl-perf-suite.sh`](../../../run-rccl-perf-suite.sh)
