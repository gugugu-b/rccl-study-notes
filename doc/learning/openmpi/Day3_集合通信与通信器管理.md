# Day 3：集合通信与通信器深度管理

> 所属计划：OpenMPI 7天深入学习计划
>
> 前置要求：掌握 Day 2 点对点通信与协议原理，理解阻塞与非阻塞的区别。

---

## 学习目标

- 熟练掌握 MPI 核心集合通信算子（Broadcast, Gather, Scatter, Allgather, Reduce, Allreduce, AlltoAll）的语义与内存布局
- 理解 `MPI_IN_PLACE` 原地操作以大幅节省大内存传输开销
- 掌握 MPI-3 非阻塞集合通信（Non-blocking Collectives: `MPI_Iallreduce` 等）
- 掌握通信器（Communicator）切分机制：`MPI_Comm_split` 与 `MPI_Comm_split_type`（创建节点内共享内存子通信域）

---

## 任务清单

### 3.1 集合通信语义与数据流动全景（2小时）

集合通信涉及通信域内所有 Rank 的协同运作。在 OpenMPI 中，所有集合通信默认具有一致的参与语义：

```
1. 一对多 (One-to-All)
   - MPI_Bcast:    Root [D0]          ──> Rank 0 [D0], Rank 1 [D0], Rank 2 [D0]
   - MPI_Scatter:  Root [D0|D1|D2]    ──> Rank 0 [D0], Rank 1 [D1], Rank 2 [D2]

2. 多对一 (All-to-One)
   - MPI_Gather:   Rank 0 [D0], Rank 1 [D1] ──> Root [D0|D1]
   - MPI_Reduce:   Rank 0 [D0], Rank 1 [D1] ──> Root [D0 ⊕ D1] (⊕ 为归约算子)

3. 多对多 (All-to-All)
   - MPI_Allgather:Rank 0 [D0], Rank 1 [D1] ──> All Ranks [D0|D1]
   - MPI_Allreduce:Rank 0 [D0], Rank 1 [D1] ──> All Ranks [D0 ⊕ D1]
   - MPI_Alltoall: 每个 Rank 将第 j 块切片发给 Rank j（矩阵转置/全交换）
```

- **原地操作（In-Place）**：
  在显存或海量内存处理时，避免开辟两倍 buffer。使用 `MPI_IN_PLACE` 作为发送缓冲区：
  ```c
  // 所有 Rank 的 recv_buf 初始存放各自的数据
  // 归约完成后，各个 Rank 的 recv_buf 直接被最终结果原地覆盖
  MPI_Allreduce(MPI_IN_PLACE, buffer, N, MPI_FLOAT, MPI_SUM, MPI_COMM_WORLD);
  ```

### 3.2 非阻塞集合通信（Non-blocking Collectives, MPI-3）（1.5小时）

在大模型分布式训练或超算数值计算中，集合通信的延迟往往会阻塞整个流水线。MPI-3 引入了非阻塞集合通信（前缀加 `I`）：

```c
#include <mpi.h>

void async_gradient_sync(float* gradients, int N) {
    MPI_Request req;

    // 1. 发起非阻塞 Allreduce 梯度聚合
    MPI_Iallreduce(MPI_IN_PLACE, gradients, N, MPI_FLOAT, MPI_SUM,
                   MPI_COMM_WORLD, &req);

    // 2. 执行与梯度聚合无依赖的其他计算（如模型评估、上一层权重更新等）
    // compute_independent_work();

    // 3. 阻塞等待集合通信完成
    MPI_Wait(&req, MPI_STATUS_IGNORE);
}
```

- **优势**：
  1. 消除传统 `MPI_Barrier` 隐式同步导致的木桶效应（慢节点让所有快节点等待）。
  2. 实现真正跨网络的高效流水线计算。

### 3.3 通信器切分（Communicator Splitting）（1.5小时）

`MPI_COMM_WORLD` 包含全局所有进程。在实际系统部署（特别是多机多 GPU 场景）中，需要将全局 Rank 划分为**节点内子通信域**与**节点间领导者通信域**：

```c
#include <mpi.h>
#include <stdio.h>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int global_rank, global_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &global_rank);
    MPI_Comm_size(MPI_COMM_WORLD, &global_size);

    // 方式一：利用系统物理拓扑标准切分（按共享内存域划分，即同一物理机划入一个 sub-comm）
    MPI_Comm node_comm;
    MPI_Comm_split_type(MPI_COMM_WORLD, MPI_COMM_TYPE_SHARED, 0,
                        MPI_INFO_NULL, &node_comm);

    int local_rank, local_size;
    MPI_Comm_rank(node_comm, &local_rank);
    MPI_Comm_size(node_comm, &local_size);

    printf("Global Rank %d is Local Rank %d on this host (Local Size: %d)\n",
           global_rank, local_rank, local_size);

    // 方式二：跨节点 Leader 组网（选出每台机器的 Local Rank 0）
    MPI_Comm leader_comm;
    int is_leader = (local_rank == 0) ? 1 : MPI_UNDEFINED;
    MPI_Comm_split(MPI_COMM_WORLD, is_leader, global_rank, &leader_comm);

    if (local_rank == 0) {
        int leader_rank, leader_size;
        MPI_Comm_rank(leader_comm, &leader_rank);
        MPI_Comm_size(leader_comm, &leader_size);
        printf(">>> Leader Rank %d of %d (Global Rank %d)\n",
               leader_rank, leader_size, global_rank);
        MPI_Comm_free(&leader_comm);
    }

    MPI_Comm_free(&node_comm);
    MPI_Finalize();
    return 0;
}
```

- 理解为何两级分层归约（Hierarchical Reduction：节点内先归约，节点间 Leader 归约，最后节点内广播）是大规模超算降低网络链路拥塞的标准范式。

### 3.4 笛卡尔拓扑（Cartesian Topology）（1小时）

- 科学计算网格划分利器：`MPI_Cart_create`、`MPI_Cart_coords`、`MPI_Cart_shift`。
- 自动处理多维网格周期性边界（Periodic Boundary）通信邻居查询。

---

## 今日产出

- [ ] 编写测试代码验证 `MPI_IN_PLACE` 在 `MPI_Allreduce` 中的正确性
- [ ] 编写并运行 `MPI_Comm_split_type` 脚本，在双机或单机多核上打印全局 Rank 与局部 Local Rank 映射
- [ ] 绘制两层分层集合通信（Hierarchical Collectives）拓扑结构示意图
- [ ] 掌握 `MPI_Iallreduce` 与 `MPI_Wait` 的异步调度模式

---

## 思考题

1. 在调用 `MPI_Reduce` 时，为什么只有 Root 节点需要开辟足够容纳最终结果的接收缓冲区，而其他 Rank 可以传入 `NULL`？
2. `MPI_Comm_split(MPI_COMM_WORLD, color, key, &newcomm)` 中，`color` 和 `key` 分别起什么作用？如果一个 Rank 传入 `MPI_UNDEFINED` 作为 `color`，会发生什么？
3. 对比 OpenMPI 的 `MPI_Allreduce` 与 RCCL 的 `ncclAllReduce`：两者在实现数据并行（Data Parallelism）分布式训练时各有什么优缺点？

---

## 参考阅读

- [MPI 集合通信标准指南](https://www.mpi-forum.org/docs/mpi-4.0/mpi40-report.pdf)
- [OpenMPI 集合通信模块（coll）说明](https://docs.open-mpi.org/en/v5.0.x/installing-open-mpi/configure-cli-options/coll.html)
