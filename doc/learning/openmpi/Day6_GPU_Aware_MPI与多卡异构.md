# Day 6：GPU-Aware MPI 与多卡异构计算

> 所属计划：OpenMPI 7天深入学习计划
>
> 核心目标：理解 GPU-Aware MPI 的显存直接寻址机制（ROCm / 海光 DTK / CUDA），搞清它与 RCCL/NCCL 的协同分工。

---

## 学习目标

- 搞懂传统 MPI 与 GPU-Aware MPI 的本质性能差异（避免 CPU Host 显存来回搬运）
- 剖析 GPU-Aware MPI 底层加速原理：节点内 HIP/CUDA IPC 与跨节点 GPUDirect RDMA（GDR）
- 编写 GPU-Aware MPI 程序，直接使用设备显存指针进行点对点与集合通信
- 深入理解 OpenMPI 与 RCCL/NCCL 的分工协同与互补关系

---

## 任务清单

### 6.1 什么是 GPU-Aware MPI？（1.5小时）

在没有 GPU-Aware 支持的传统 MPI 时代，GPU 上的数据通信必须由 CPU 显存中转（Staging）：

```
传统非 GPU-Aware 流程 (低效，4 次跨总线内存拷贝 + CPU 频繁介入)
[GPU 0 显存] ──PCIe/D2H──> [Host 内存 0] ──MPI_Send/网络──> [Host 内存 1] ──PCIe/H2D──> [GPU 1 显存]

─────────────────────────────────────────────────────────────────────────────

GPU-Aware MPI 流程 (直通零拷贝)
- 节点内: [GPU 0 显存] ═══════ xGMI / HSL / PCIe P2P ═══════> [GPU 1 显存] (纯硬件互联直写)
- 跨节点: [GPU 0 显存] ═══════ GPUDirect RDMA (GDR) ════════> [GPU 1 显存] (网卡 DMA 直通显存)
```

- **核心价值**：
  1. **超低小包延迟**：省去 Host-to-Device 与 Device-to-Host 数据拷贝与同步开销。
  2. **解放 CPU 核心**：数据完全由 GPU DMA 引擎或 RDMA 网卡推进，CPU 不参与内存搬运。
  3. **编程代码极大精简**：可以直接将 `hipMalloc` 或 `cudaMalloc` 返回的设备指针作为 `MPI_Send`、`MPI_Recv`、`MPI_Allreduce` 的缓冲区参数！

### 6.2 编译与环境验证（1.5小时）

要支持 GPU-Aware，底层通信库 UCX 与 OpenMPI 必须在编译时开启对应的 GPU 驱动支持：

```shell
# 1. 验证当前 OpenMPI 是否已编译 GPU-Aware 支持
ompi_info --parsable --all | grep -i "built_with_cuda_support:value"
# 输出如果是 true，说明支持显存直接传参

# 2. 如果使用 UCX 后端，检查 UCX 的 CUDA/ROCm 模块
ucx_info -d | grep -E "cuda|rocm"

# 3. 运行时的环境变量开启（必要条件！）
# AMD ROCm / 海光 DTK 环境：
export OMPI_MCA_pml=ucx
export UCX_TLS=rc,sm,self,rocm_copy,rocm_ipc
# 如果跨机支持 GPUDirect RDMA：
export UCX_IB_GPU_DIRECT_RDMA=yes
```

### 6.3 编写 GPU-Aware Ping-Pong 实测程序（2小时）

编写 `gpu_ping_pong.cpp`（以 HIP 编程为例，完全兼容海光 DTK 与 AMD ROCm）：

```cpp
#include <mpi.h>
#include <hip/hip_runtime.h>
#include <stdio.h>
#include <stdlib.h>

#define HIP_CHECK(cmd) do { \
    hipError_t err = cmd; \
    if (err != hipSuccess) { \
        fprintf(stderr, "HIP error %s:%d '%s'\n", __FILE__, __LINE__, hipGetErrorString(err)); \
        exit(EXIT_FAILURE); \
    } \
} while(0)

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    if (size < 2) {
        if (rank == 0) printf("Error: Requires at least 2 ranks.\n");
        MPI_Finalize();
        return 1;
    }

    // 1. 绑定当前进程到对应物理 GPU/DCU 卡
    HIP_CHECK(hipSetDevice(rank % 8));

    size_t bytes = 64 * 1024 * 1024; // 64 MB 数据包
    void* d_buf = nullptr;

    // 2. 直接在设备显存（HBM/VRAM）中分配内存
    HIP_CHECK(hipMalloc(&d_buf, bytes));
    HIP_CHECK(hipMemset(d_buf, rank + 1, bytes));

    MPI_Barrier(MPI_COMM_WORLD);
    double t_start = MPI_Wtime();

    int iters = 50;
    for (int i = 0; i < iters; i++) {
        if (rank == 0) {
            // 3. 关键：直接传入设备显存指针 d_buf！
            MPI_Send(d_buf, bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD);
            MPI_Recv(d_buf, bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        } else if (rank == 1) {
            MPI_Recv(d_buf, bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            MPI_Send(d_buf, bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD);
        }
    }

    double t_end = MPI_Wtime();
    if (rank == 0) {
        double elapsed = t_end - t_start;
        double latency_us = (elapsed / (2.0 * iters)) * 1e6;
        double bw_gbs = (bytes / 1e9) / (elapsed / (2.0 * iters));
        printf("GPU-Aware MPI Ping-Pong (64MB):\n");
        printf("  Latency  : %.2f us\n", latency_us);
        printf("  Bandwidth: %.2f GB/s\n", bw_gbs);
    }

    HIP_CHECK(hipFree(d_buf));
    MPI_Finalize();
    return 0;
}
```

- 编译与运行：
  ```shell
  # 海光 DTK 编译：
  hipcc -I/opt/openmpi/include -L/opt/openmpi/lib -lmpi gpu_ping_pong.cpp -o gpu_ping_pong

  # 运行并观察带宽（应能跑满 PCIe 或卡间高速互联带宽）
  mpirun -np 2 ./gpu_ping_pong
  ```

### 6.4 OpenMPI 与 RCCL/NCCL 的协作分工（1小时）

既然 GPU-Aware MPI 已经能够直接在显存上通信，**为什么深度学习大模型训练还需要专门的 RCCL/NCCL？**

| 维度 | GPU-Aware OpenMPI | RCCL / NCCL |
|---|---|---|
| **首要设计目标** | 全功能通用通信标准（P2P、拓扑图、稀疏传输、I/O） | 极致的高吞吐 Dense 张量集合通信（梯度同步、张量切片） |
| **内核执行模型** | 通信逻辑主要在 CPU 侧调度（即使有 GDR，也是 CPU 触发 DMA） | 通信逻辑深度整合进 GPU Kernel 内部执行（线程块自同步、寄存器级归约） |
| **算法优化深度** | 偏通用树形/二项分布算法，难以根据非对称 GPU 拓扑极致定制 Ring | 针对 NVLink/xGMI/HSL 拓扑动态搜索多环（Multi-Ring）与流水线 Channel |
| **现代大模型分工** | **控制面（Control Plane）**：负责集群进程拉起、环境变量分发、带外建连 | **数据面（Data Plane）**：接管所有模型张量的高速集合通信 |

---

## 今日产出

- [ ] 验证本地 OpenMPI / UCX 是否具备 GPU-Aware 编译能力
- [ ] 成功编写、编译并运行 `gpu_ping_pong.cpp`
- [ ] 对比 Host 内存 Ping-Pong 与 GPU 显存 Ping-Pong 的带宽/延迟差异
- [ ] 梳理 GPU-Aware MPI 在科学计算与 AI 架构中的定位文档

---

## 思考题

1. 当将一个显存指针传给 `MPI_Send` 时，MPI 是如何知道这个指针指向的是 Host 内存还是 Device 显存的？（提示：了解统一虚拟寻址 UVA 与 `hipPointerGetAttributes`）
2. GPUDirect RDMA（GDR）对操作系统内核模块（如 `nv_peer_mem` 或 AMD 的 `amdgpu` Direct DMA）有什么依赖？如果未加载内核模块会发生什么？
3. 如果一个模型训练任务只需要做简单的双卡异步张量传输，使用 GPU-Aware MPI 和使用 RCCL 哪种开发成本更低？为什么？

---

## 参考阅读

- [NVIDIA Developer - Introduction to CUDA-Aware MPI](https://developer.nvidia.com/blog/introduction-cuda-aware-mpi/)
- [AMD ROCm-Aware MPI 指南](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/how-to/3rd-party/openmpi.html)
- [OpenMPI 官方 GPU-Aware FAQ](https://www.open-mpi.org/faq/?category=openfabrics#cuda)
