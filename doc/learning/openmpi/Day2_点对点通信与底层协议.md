# Day 2：点对点通信与底层传输协议

> 所属计划：OpenMPI 7天深入学习计划
>
> 前置要求：完成 Day 1 环境搭建，掌握基本 C/C++ 语法与编译流程。

---

## 学习目标

- 深入理解阻塞通信与非阻塞通信（Non-blocking）的本质差异
- 掌握 4 种发送模式（标准、同步、缓冲、就绪）的使用边界
- 剖析底层两大核心传输协议：**Eager（渴望）协议** 与 **Rendezvous（会合）协议**
- 编写 Ping-Pong 测试程序测量延迟与带宽，掌握死锁分析与避免策略

---

## 任务清单

### 2.1 阻塞通信与死锁陷阱（1.5小时）

- **标准阻塞通信**：
  ```c
  int MPI_Send(const void *buf, int count, MPI_Datatype datatype,
               int dest, int tag, MPI_Comm comm);
  int MPI_Recv(void *buf, int count, MPI_Datatype datatype,
               int source, int tag, MPI_Comm comm, MPI_Status *status);
  ```
  - `MPI_Send` 所谓的"阻塞"，是指发送缓冲区 `buf` 何时可以被安全复用，并不等价于"接收方已收到数据"！
  - `MPI_Recv` 是真正的阻塞，直到数据完整拷贝进目标缓冲区才返回。

- **经典双向交换死锁陷阱**：
  ```c
  // 错误示范：Rank 0 与 Rank 1 互发数据
  if (rank == 0) {
      MPI_Send(send_buf, N, MPI_FLOAT, 1, 0, MPI_COMM_WORLD);
      MPI_Recv(recv_buf, N, MPI_FLOAT, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
  } else if (rank == 1) {
      MPI_Send(send_buf, N, MPI_FLOAT, 0, 0, MPI_COMM_WORLD);
      MPI_Recv(recv_buf, N, MPI_FLOAT, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
  }
  ```
  - **现象**：当 $N$ 较小时（几 KB），程序能正常运行；当 $N$ 增大到几 MB 时，程序必定永久挂起（死锁）！
  - **原因**：底层协议从 Eager 自动切换为 Rendezvous，双方都在等待对端响应握手，导致循环等待死锁。

- **死锁解决方案**：
  1. 使用标准交错顺序（Rank 0 先发后收，Rank 1 先收后发）。
  2. 使用组合操作 `MPI_Sendrecv`（底层自动交错调度）。
  3. 使用非阻塞通信（Non-blocking）。

### 2.2 非阻塞通信与重叠计算（1.5小时）

非阻塞通信是实现通信与计算重叠（Overlap Computation and Communication）的基石：

```c
#include <mpi.h>
#include <stdio.h>

void non_blocking_exchange(float* send_buf, float* recv_buf, int N, int peer) {
    MPI_Request reqs[2];
    MPI_Status stats[2];

    // 1. 发起非阻塞接收（立即返回，不等待数据到达）
    MPI_Irecv(recv_buf, N, MPI_FLOAT, peer, 0, MPI_COMM_WORLD, &reqs[0]);

    // 2. 发起非阻塞发送（立即返回，不可立即修改 send_buf）
    MPI_Isend(send_buf, N, MPI_FLOAT, peer, 0, MPI_COMM_WORLD, &reqs[1]);

    // 3. 在通信进行期间，CPU/GPU 可以执行重叠的本地独立计算！
    // do_local_computation();

    // 4. 等待发送和接收全部完成
    MPI_Waitall(2, reqs, stats);
}
```

- 理解 `MPI_Request` 句柄的作用与生命周期。
- 掌握等待与测试函数：`MPI_Wait`、`MPI_Waitall`、`MPI_Waitany`、`MPI_Test`。

### 2.3 底层核心协议剖析：Eager vs Rendezvous（2小时）

OpenMPI 的底层传输层（如 UCX 或 BTL）根据消息大小决定采用哪种协议：

```
Eager 协议 (小消息 < 阈值，如 < 12KB)
Sender ─────── Header + Data (直接投递) ───────> Receiver (存入临时 Unexpected 队列)
                                                      │
Sender 立即返回                                      ▼
                                             后调用的 MPI_Recv 从队列提取拷贝

─────────────────────────────────────────────────────────────────────────────

Rendezvous 协议 (大消息 >= 阈值)
Sender ─────── RTS (Ready to Send 请求) ───────> Receiver
                                                      │ 确认已有匹配的 MPI_Recv
Sender <────── CTS (Clear to Send 许可) ─────── Receiver
  │
  ▼
Sender ═══════ RDMA Read/Write 直接显存/内存穿透 ═════> Receiver 缓冲区
  │
  ▼
Sender ─────── FIN (完成通知) ─────────────────> Receiver
```

| 特性 | Eager 协议（渴望协议） | Rendezvous 协议（会合协议） |
|---|---|---|
| **适用包长** | 小消息（通常 $< 8\text{KB} \sim 64\text{KB}$） | 大消息（数 MB 到数 GB） |
| **通信延迟** | 极低（仅需 1 次网络单程往返传输） | 相对较高（需要 3 次握手协商：RTS $\to$ CTS $\to$ Data $\to$ FIN） |
| **内存开销** | 接收端需要预先分配缓冲池，接收意外消息（Unexpected Buffer） | 零拷贝（Zero-copy），直接由源地址通过 DMA 写入目的地址 |
| **缓冲区溢出风险**| 若接收端迟迟不投递 Recv，缓冲池耗尽会导致 OOM 或挂起 | 安全无溢出风险，流控天然保障 |
| **调优参数** | `btl_vader_eager_limit`、`pml_ucx_eager_limit` 等 | 超过此阈值自动启用 RDMA 会合通道 |

### 2.4 实战：手写 Ping-Pong 延迟与带宽测量工具（1小时）

编写 `ping_pong.c`，测量节点内（共享内存）与节点间（网络）的通信延迟与带宽：

```c
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

#define WARMUP 10
#define ITERS 100

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);
    int rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    size_t sizes[] = {8, 64, 512, 4096, 65536, 1048576, 16777216}; // 8B ~ 16MB
    int num_sizes = sizeof(sizes) / sizeof(sizes[0]);

    if (rank == 0) {
        printf("%-12s %-15s %-15s\n", "Size (Bytes)", "Latency (us)", "Bandwidth (MB/s)");
        printf("----------------------------------------------------\n");
    }

    for (int i = 0; i < num_sizes; i++) {
        size_t bytes = sizes[i];
        char* buf = (char*)malloc(bytes);

        // 热身
        for (int w = 0; w < WARMUP; w++) {
            if (rank == 0) {
                MPI_Send(buf, bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD);
                MPI_Recv(buf, bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            } else if (rank == 1) {
                MPI_Recv(buf, bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                MPI_Send(buf, bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD);
            }
        }

        MPI_Barrier(MPI_COMM_WORLD);
        double t_start = MPI_Wtime();

        for (int it = 0; it < ITERS; it++) {
            if (rank == 0) {
                MPI_Send(buf, bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD);
                MPI_Recv(buf, bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            } else if (rank == 1) {
                MPI_Recv(buf, bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                MPI_Send(buf, bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD);
            }
        }

        double t_end = MPI_Wtime();
        double elapsed = t_end - t_start;
        double latency_us = (elapsed / (2.0 * ITERS)) * 1e6;
        double bw_mbs = (bytes / (1024.0 * 1024.0)) / (elapsed / (2.0 * ITERS));

        if (rank == 0) {
            printf("%-12zu %-15.3f %-15.2f\n", bytes, latency_us, bw_mbs);
        }
        free(buf);
    }

    MPI_Finalize();
    return 0;
}
```

---

## 今日产出

- [ ] 编写并运行 `ping_pong.c`，获取单机 2 进程（共享内存）实测延迟与带宽曲线
- [ ] 跨机运行 `ping_pong.c`，观察网络小包往返延迟（RTT）与大包吞吐上限
- [ ] 记录 Eager 切换到 Rendezvous 时的延迟阶跃拐点
- [ ] 分析死锁案例并使用 `MPI_Sendrecv` 与 `MPI_Isend/Irecv` 成功修复

---

## 思考题

1. 为什么 Rendezvous 协议对大消息能够实现"零拷贝"？数据是怎么从 Sender 显存/内存直接落到 Receiver 内存的？
2. 如果把 Eager 协议的阈值设得极大（如 100MB），会发生什么严重后果？
3. `MPI_Bsend` 里的 "B"（Buffered）与操作系统内核的 Socket 发送缓冲区有什么关系？用户必须调用什么 API 才能使用 `MPI_Bsend`？

---

## 参考阅读

- [MPI 标准规范 - Point-to-Point Communication](https://www.mpi-forum.org/docs/mpi-4.0/mpi40-report.pdf)
- [OpenMPI FAQ - Tuning point-to-point performance](https://www.open-mpi.org/faq/?category=tuning)
- [OSU Micro-Benchmarks 主页](https://mvapich.cse.ohio-state.edu/benchmarks/)
