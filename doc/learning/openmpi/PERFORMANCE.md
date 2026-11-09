# OpenMPI 性能指标详解与评估基准

> 本文档用于定义 OpenMPI 通信性能的核心评测指标、通信模型理论公式与典型硬件基准参考。

---

## 一、核心性能指标

与面向纯 Dense 矩阵吞吐的集合通信库（如 RCCL）不同，OpenMPI 作为通用消息传递中间件，评估维度涵盖**点对点延迟**、**双向带宽**、**消息吞吐率**以及**集合通信扩展性**。

### 1. 单程延迟（Latency / $\alpha$）
- **定义**：从发送进程提交消息开始，到接收进程完整收到该消息所需的单程时间（通常以微秒 $\mu\text{s}$ 计量）。
- **测量方法**：通过 Ping-Pong 往返测试，测得双向往返时间 $RTT$（Round-Trip Time），单程延迟取：
  $$\text{Latency} = \frac{RTT}{2}$$
- **物理意义**：衡量网络软件协议栈开销、网卡驱动注入开销与物理链路传输延迟。主要关注极小包（8 字节至 64 字节）。

### 2. 单向与双向带宽（Unidirectional / Bi-directional Bandwidth）
- **单向带宽（Bandwidth）**：
  $$\text{Bandwidth (GB/s)} = \frac{\text{Message Size (Bytes)}}{\text{Transfer Time (s)} \times 10^9}$$
- **双向带宽（Bi-directional Bandwidth / Bi-bw）**：双方节点同时向对方持续轰发大数据包时各自测得的聚合吞吐。用于检验全双工（Full-Duplex）物理链路与 PCIe 双向吞吐能力。

### 3. 消息率（Message Rate / Mpps）
- **定义**：单位时间内系统每秒能够处理和发送的消息包数量（以百万包每秒 $\text{Million packets/s}$ 计量）。
- **物理意义**：衡量 CPU 单核协议栈处理效率与网卡队列硬件中断/轮询能力的上限，对稀疏图遍历、粒子模拟等细粒度计算至关重要。

---

## 二、通信理论模型：Hockney 与 LogGP

在并行计算性能建模中，常用两大经典模型预测通信耗时：

### 1. Hockney 线性模型
$$T(S) = \alpha + \frac{S}{\beta}$$
- $S$：消息大小（Bytes）
- $\alpha$：启动延迟（Startup Latency，与包大小无关的常数项）
- $\beta$：渐进网络带宽（Asymptotic Bandwidth，即链路峰值吞吐上限）

### 2. LogGP 模型（面向现代高速网络）
- **L (Latency)**：网络底层物理传输延迟
- **o (Overhead)**：CPU 参与通信协议处理所占用的不可重叠时间
- **g (Gap)**：连续发送两个消息之间的最小时间间隔（$1/g$ 即为网卡硬件消息注入率）
- **G (Gap per Byte)**：每传输一个字节所需的额外耗时（$1/G$ 即为硬件传输带宽）
- **P (Processors)**：通信域内的进程数量

---

## 三、各层级互联典型性能参考

| 通信媒介 | 底层组件 / 技术 | 8B 延迟（典型值） | 峰值带宽（单向） | 瓶颈特征 |
|---|---|---|---|---|
| **节点内进程间** | BTL vader（CMA / POSIX SHM） | **0.15 ~ 0.35 $\mu\text{s}$** | 25 ~ 50 GB/s | 受限于 CPU 内存控制器与 L3 Cache 带宽 |
| **千兆 / 万兆以太网** | BTL tcp（标准 TCP/IP 协议栈） | 15.0 ~ 30.0 $\mu\text{s}$ | 0.1 ~ 1.1 GB/s | 受内核上下文切换与 Socket 协议栈开销限制 |
| **25G / 100G RoCEv2** | PML ucx + UCT rc（RDMA 旁路内核） | **1.8 ~ 3.5 $\mu\text{s}$** | 2.8 ~ 11.8 GB/s | 受网络拥塞控制（PFC/ECN）与网卡 PCIe 影响 |
| **200G / 400G InfiniBand** | PML ucx + Native IB（HDR/NDR） | **0.8 ~ 1.2 $\mu\text{s}$** | 24 ~ 48 GB/s | 硬件直通极低延迟，接近物理光纤极限 |
| **节点内 GPU-Aware** | HIP / CUDA IPC（xGMI / HSL / NVLink） | **0.5 ~ 1.0 $\mu\text{s}$** | 50 ~ 200 GB/s | 纯硬件卡间互联直写，无需任何 CPU 拷贝 |
| **跨节点 GPU-Aware** | GPUDirect RDMA（GDRDMA） | **2.0 ~ 4.0 $\mu\text{s}$** | 等同 RDMA 网络线速 | 显存与网卡直接 DMA，绕过 Host 内存 |

---

## 四、权威测试工具对比

在生产环境进行通信评测与验收时，推荐按场景选择以下基准测试工具：

| 工具名称 | 核心测试项 | 特点与适用场景 |
|---|---|---|
| **OSU Micro-Benchmarks (OMB)** | `osu_latency`, `osu_bw`, `osu_bibw`, `osu_allreduce` | **超算与 HPC 业界标准**。支持 CPU 内存与 GPU 显存（CUDA/ROCm）直接基准压测。 |
| **Intel MPI Benchmarks (IMB)** | `IMB-MPI1`, `IMB-EXT`, `IMB-NBC` | 覆盖更全面的 MPI-1 至 MPI-3 非阻塞与单边通信测试套件。 |
| **rccl-tests / nccl-tests** | `all_reduce_perf`, `all_gather_perf` 等 | **AI 大模型集合通信专属**。专注于多卡高并发下的总线带宽利用率（busBw）。 |
| **Perftest (ibv_rc_pingpong 等)** | `ib_write_bw`, `ib_read_lat` | **底层物理网络硬件纯测**。绕过 MPI 协议栈，直接测试 Mellanox/RDMA 网卡本身的物理能力。 |
