# Day 4：MCA 模块化架构深度剖析

> 所属计划：OpenMPI 7天深入学习计划
>
> 核心目标：掌握 OpenMPI 最灵魂的设计范式——模块化组件架构（MCA），从源码级理清框架、组件、模块的协作逻辑。

---

## 学习目标

- 深入理解 OpenMPI 的三大主体软件层：OPAL、ORTE/PRRTE、OMPI
- 彻底掌握 MCA（Modular Component Architecture）的设计哲学与生命周期
- 搞懂 Framework（框架）、Component（组件）、Module（模块）的三元关系
- 熟练使用 `ompi_info` 检索、分析和动态注入 MCA 运行时参数

---

## 任务清单

### 4.1 OpenMPI 的三大分层体系（1.5小时）

OpenMPI 的代码库并没有把所有逻辑混杂在一起，而是划分成严格解耦的三个层次：

```
┌──────────────────────────────────────────────────────────────┐
│                    OMPI (Open MPI Layer)                     │
│  - 实现 MPI-1 ~ MPI-4 规范的所有公开 API                      │
│  - 负责 Communicator、Datatype、Group、Op 的高级管理          │
│  - 包含 pml, mtl, btl, coll, osc 等通信框架                   │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│               ORTE / PRRTE (Runtime Environment)             │
│  - 运行时控制面：实现 mpirun / orted / prun                   │
│  - 集群节点发现、作业排队、进程启动与监控、标准 I/O 汇聚重定向 │
│  - 包含 plm (进程生命周期), ras (资源分配), oob (带外控制通信) │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│              OPAL (Open Portable Access Layer)               │
│  - 跨平台操作系统抽象与底层支撑层                              │
│  - 高性能基础数据结构（无锁环形队列、B树、基数树、哈希表）      │
│  - hwloc 硬件拓扑感知、内存分配器追踪、事件循环 (libevent)    │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 什么是 MCA（Modular Component Architecture）（2小时）

MCA 是 OpenMPI 具有极强扩展性和硬件适应性的核心所在。几乎所有底层功能都是作为独立插件（DSO 动态链接库或静态内置组件）挂载在 MCA 之上的：

```
                    ┌─────────────────────────┐
                    │      MCA 核心管理层      │
                    └────────────┬────────────┘
                                 │ 发现 / 选择 / 优先级决策
     ┌───────────────────────────┼───────────────────────────┐
     ▼                           ▼                           ▼
PML (点对点管理框架)         BTL (底层字节传输框架)       COLL (集合通信框架)
 ├── ucx (高优先级)           ├── vader (共享内存)        ├── tuned (自适应微调)
 ├── ob1 (通用重组)           ├── openib (RDMA，旧版)     ├── basic (基础算法)
 └── cm  (匹配传输层代理)     └── tcp   (网络降级)        └── libnbc (非阻塞集合)
```

- **三元定义**：
  1. **Framework（框架）**：定义一类功能的标准 C 接口规范（函数指针结构体）。例如 `btl` 规定了字节传输接口，`coll` 规定了集合通信算法接口。
  2. **Component（组件）**：该框架的一个具体算法或硬件实现。每个组件包含一个描述符（如 `mca_btl_vader_component`），对外暴露版本、可用性检查与初始化函数。
  3. **Module（模块）**：当组件通过测试、被选拔成功后，在运行时动态实例化出的执行对象。

- **组件选拔机制（Selection / Priority）**：
  - 每个组件都有一个静态或动态评定的 `priority`（优先级，如 0~100）。
  - 在 `MPI_Init` 阶段，各框架会调用所有已编译组件的 `open` 和 `init` 钩子函数探测本地硬件可用性。
  - 优先级最高的可用组件将被选中；如果支持多组件协同（如多个 BTL 分别负责共享内存与以太网），则会同时加载并按权重绑定。

### 4.3 `ompi_info` 诊断与参数查看利器（1.5小时）

`ompi_info` 是 OpenMPI 中最重要但也最容易被忽视的诊断工具：

```shell
# 1. 查看 OpenMPI 整体编译信息、编译器标志与支持的 MCA 框架列表
ompi_info

# 2. 列出当前安装的所有通信框架及其包含的组件
ompi_info --type framework

# 3. 查看点对点传输框架 PML 的所有可选组件
ompi_info --param pml all

# 4. 查看底层字节传输 BTL 的所有组件和每个参数的默认值、可调节范围与释义
ompi_info --param btl all --level 9

# 5. 精确查看共享内存组件 vader 的参数详情
ompi_info --param btl vader --level 9
```

### 4.4 MCA 参数配置的三种层级（1小时）

MCA 参数允许从外部无缝控制 OpenMPI 底层的每一个行为细节。其生效优先级依次为：

1. **CLI 命令行参数（最高优先级）**：
   ```shell
   # 强制指定使用 UCX 作为点对点消息层，并屏蔽旧版 openib
   mpirun --mca pml ucx --mca btl ^openib -np 4 ./hello_mpi
   ```
   *注：`^` 符号表示“排除/禁用”该组件。*

2. **环境变量（第二优先级）**：
   ```shell
   export OMPI_MCA_pml=ucx
   export OMPI_MCA_btl="vader,self"
   mpirun -np 4 ./hello_mpi
   ```

3. **配置文件（全局默认配置）**：
   - 系统级配置文件：`/opt/openmpi/etc/openmpi-mca-params.conf`
   - 用户级配置文件：`~/.openmpi/mca-params.conf`
   - 文件内容格式示例：
     ```ini
     btl = vader,self
     pml = ucx
     hwloc_base_binding_policy = core
     ```

---

## 今日产出

- [ ] 运行 `ompi_info` 输出当前环境包含的所有 MCA 框架与组件清单
- [ ] 掌握 `pml`、`btl`、`coll`、`plm`、`ras` 五大常用框架的功能定位
- [ ] 实践通过命令行 `--mca` 与环境变量 `OMPI_MCA_` 切换底层传输组件
- [ ] 绘制 MCA 组件加载、探测、优先级决策到实例化的生命周期流程图

---

## 思考题

1. 在 `mpirun` 参数中，`--mca btl tcp,self` 与 `--mca btl ^openib` 分别代表什么含义？
2. 为什么说 MCA 的插件化机制是 OpenMPI 能同时高效运行于笔记本单机、以太网云服务器和 InfiniBand 顶尖超算的核心秘密？
3. 如果一个高优先级的网络组件探测到网卡缺失（例如配置了 IB 但机器只有普通网卡），OpenMPI 的 MCA 会直接崩溃报错，还是会自动回退到降级组件？内部逻辑是怎样的？

---

## 参考阅读

- [OpenMPI MCA 官方架构白皮书](https://www.open-mpi.org/papers/euro-pvmmpi-2004-overview/)
- [OpenMPI 5.0 MCA 参数手册](https://docs.open-mpi.org/en/v5.0.x/tuning-apps/environment-var.html)
