# Day 2：集合操作语义与测试框架

> 所属计划：RCCL 7天深入学习计划

---

## 学习目标
- 彻底理解 8 种集合操作的数据流向与数学语义
- 读懂 rccl-tests 的代码架构（testColl / testEngine / threadArgs）
- 能修改测试参数并理解其对结果的影响

---

## 任务清单

### 2.1 梳理集合操作语义（2小时）
对照 `src/` 下每个 `.cu` 文件，画出每种操作的数据流向图：

| 操作 | 文件 | 语义 | 是否有 root |
|---|---|---|:---:|
| AllReduce | `all_reduce.cu` | 所有 rank 得到相同的归约结果 | 否 |
| AllGather | `all_gather.cu` | 每个 rank 收集所有 rank 的数据 | 否 |
| ReduceScatter | `reduce_scatter.cu` | 归约后分散到各 rank | 否 |
| Broadcast | `broadcast.cu` | root 数据广播到所有 rank | 是 |
| Reduce | `reduce.cu` | 归约到 root | 是 |
| AlltoAll | `alltoall.cu` | 全交换 | 否 |
| Gather/Scatter | `gather.cu`/`scatter.cu` | 收集/分散 | 是 |
| SendRecv | `sendrecv.cu` | 点对点 | - |

- 每个操作画出 N=4 rank 的数据流示意图（手画即可）

### 2.2 精读测试框架源码（2小时）
- 精读 `src/common.h`：重点理解 `testColl`、`testEngine`、`threadArgs` 三个结构体
- 精读 `src/common.cu`：理解 `TimeTest`、`Barrier`、`AllocateBuffs`、`InitData` 的作用
- 理解多进程×多线程×多GPU的层级关系：`totalRanks = nProcs × nThreads × nGpus`

### 2.3 深入读一个完整测试（1小时）
以 `src/all_reduce.cu` 为例，逐行理解：
- `AllReduceGetCollByteCount`：如何计算发送/接收字节数
- `AllReduceInitData`：如何初始化输入和期望输出
- `AllReduceGetBw`：带宽如何计算（注意 `2*(n-1)/n` 因子）
- `AllReduceRunColl`：实际调用 `ncclAllReduce`
- `AllReduceRunTest`：如何遍历数据类型和操作类型

### 2.4 实验不同参数（1小时）
```shell
# 不同数据类型
./build/all_reduce_perf -d half -g 4
./build/all_reduce_perf -d bfloat16 -g 4

# 不同归约操作
./build/all_reduce_perf -o sum -g 4
./build/all_reduce_perf -o max -g 4

# 正确性检查
./build/all_reduce_perf -c 5 -g 4

# 阻塞 vs 非阻塞
./build/all_reduce_perf -z 1 -g 4
```
- 记录不同参数对性能/正确性的影响

---

## 今日产出
- [ ] 8 种集合操作的数据流向图（手画或工具绘制）
- [ ] `common.h` 三个核心结构体的字段注释文档
- [ ] `all_reduce.cu` 逐行注释版
- [ ] 参数实验结果对比表

---

## 思考题
1. `testColl` 的回调函数设计为什么能做到"一套框架测所有操作"？
2. `InitData` 如何保证归约结果可精确预测？提示：看 `verifiable/verifiable.h`
3. 为什么 AllReduce 的 busbw 因子是 `2*(n-1)/n`，而 AllGather 是 `(n-1)/n`？

---

## 参考资料
- 当前项目 `src/common.h`、`src/all_reduce.cu`
- `verifiable/verifiable.h`（可验证归约的设计思路）
