# 双机 RCCL RoCE 与 InfiniBand 测试

适用于两台 BW1100 节点，每台 8 张 DCU。先用 `ib_write_bw` 测指定网口的主机内存 RDMA，再跑双机各 1 卡的 AllReduce。冒烟通过后，扩到双机 16 卡测 AllReduce、AllGather 和 AllToAll。

镜像为 `harbor.sourcefind.cn:5443/hcu/admin/base/sglang:0.5.18-ubuntu22.04-dtk26041-py3.10`。以下路径和版本以已检查的 digest `sha256:a19a5f25ef700c8fc8f830402eb23dd698a21fc3de49b3652c78391ad177bdd7` 为准。

| 项目 | 测试基线 |
| --- | --- |
| RCCL | `2.22.3-HEAD`（`e6f150a`），`/opt/dtk/lib/librccl.so.1` |
| Open MPI | `5.0.3`，`/opt/mpi`。镜像另有 `4.1.7a1`，两套库的 SONAME 均为 `libmpi.so.40` |
| UCX 和 OFED | 镜像默认 UCX `1.15.0`，MLNX_OFED `23.10-4.0.9.1` |
| rccl-tests | 本仓库子模块对应的 `40b1b17901370a7880d4a56854b5361c89f8d324` |

管理网承载 SSH、PRRTE 控制连接、MPI 小消息和 RCCL bootstrap。RCCL 跨机数据走 `NCCL_IB_HCA` 指定的 RDMA 口。RoCEv2 和原生 InfiniBand 在这版 RCCL 中都使用 `IB` 后端。

## 1. 两台机器共同准备

### 1.1 启动测试容器

两台宿主机各执行一次。A 的 `NODE` 设为 `rccl-a`，B 设为 `rccl-b`。示例沿用 BW1100 的宿主机 `/opt/hyhal` 挂载方式，使用镜像内的 DTK。先确认宿主机的 DCU 驱动、HCA 驱动和设备节点已就绪。

```bash
NODE=rccl-a
BENCH_DIR=/data/rccl-dual
IMAGE=harbor.sourcefind.cn:5443/hcu/admin/base/sglang@sha256:a19a5f25ef700c8fc8f830402eb23dd698a21fc3de49b3652c78391ad177bdd7

mkdir -p "$BENCH_DIR"
docker run -d --name "$NODE" --hostname "$NODE" --network host \
  --device=/dev/kfd --device=/dev/dri --device=/dev/infiniband \
  --ulimit memlock=-1:-1 --shm-size=8g \
  -v /opt/hyhal:/opt/hyhal:ro -v "$BENCH_DIR:/work" -w /work \
  "$IMAGE" /bin/sleep infinity

docker exec -it "$NODE" /bin/bash
```

两端容器内执行，确认 DCU 数量、架构、HCA 和 memlock。

```bash
rocminfo | grep -E 'Name:[[:space:]]+gfx'
ibv_devices
ibstat
ulimit -l
/opt/mpi/bin/mpirun --version
```

BW1100 示例用 `gfx938`。如果容器内看不到 HCA，先对比宿主机的 `ibv_devices` 和 `/dev/infiniband`，确认容器能打开对应的 `uverbs*`。

### 1.2 记录每台机器的网口

先在两端用 `ip -br -4 addr`、`ibstat` 和 `ibdev2netdev` 查接口。各自在 `/work/node.env` 写入本机配置。下面的 IP、网口、端口号和 GID 都是示例。A 配置如下，B 按表替换对应项。只测一种网络时，填写该网络和管理网的参数即可。

```bash
CTRL_IP=192.0.2.11
CTRL_IF=eno1
CTRL_CIDR=192.0.2.0/24
PEER_CTRL_IP=192.0.2.12
SSH_PORT=22222

ROCE_HCA=mlx5_0
ROCE_PORT=1
ROCE_IF=ens6f0np0
ROCE_IP=198.51.100.11
PEER_ROCE_IP=198.51.100.12
ROCE_GID=3

IB_HCA=mlx5_1
IB_PORT=1
```

| B 上需要换成 | 示例值 |
| --- | --- |
| `CTRL_IP` / `PEER_CTRL_IP` | `192.0.2.12` / `192.0.2.11` |
| `ROCE_IP` / `PEER_ROCE_IP` | `198.51.100.12` / `198.51.100.11` |
| `CTRL_IF` / `ROCE_IF` | 本机管理网接口和承载 RoCE IP 的接口，VLAN 场景使用相应 VLAN 接口 |
| `ROCE_HCA` / `IB_HCA` | 以 B 的设备枚举为准，例如 `mlx5_2` / `mlx5_3` |
| `ROCE_PORT` / `ROCE_GID` / `IB_PORT` | 各取本机实际值，例如 `1` / `5` / `1` |

### 1.3 配置容器 SSH 并编译

两端容器各自生成测试用密钥，将对端的**公钥**加入本端 `/root/.ssh/authorized_keys`，文件权限设为 `600`。已有容器免密 SSH 时，可直接使用现有端口和身份。

```bash
source /work/node.env
install -d -m 700 /root/.ssh
test -f /root/.ssh/id_ed25519 || ssh-keygen -q -t ed25519 -N '' -f /root/.ssh/id_ed25519
cat /root/.ssh/id_ed25519.pub
```

交换公钥后，两端执行下列命令。测试端口应空闲，SSH 监听在本机管理 IP。

```bash
chmod 600 /root/.ssh/authorized_keys
mkdir -p /run/sshd
ssh-keygen -A
/usr/sbin/sshd -E /tmp/rccl-sshd.log -p "$SSH_PORT" \
  -o "ListenAddress=$CTRL_IP" -o PermitRootLogin=prohibit-password \
  -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

两端 SSH 服务都启动后，各自执行。首次互连时，对照对端输出的主机指纹确认身份，再用 `BatchMode=yes` 验证免密。

```bash
ssh -o StrictHostKeyChecking=ask -p "$SSH_PORT" "root@$PEER_CTRL_IP" /bin/hostname
ssh -o BatchMode=yes -p "$SSH_PORT" "root@$PEER_CTRL_IP" /bin/hostname
```

SSH 端口、PRRTE/MPI/RCCL bootstrap 所需的动态 TCP 连接，以及 `ib_write_bw` 默认的 TCP `18515` 都需要在两端管理 IP 间可达。 [Open MPI 5.0.3 SSH 启动说明](https://docs.open-mpi.org/en/v5.0.3/launching-apps/ssh.html) · [perftest 参数](https://github.com/linux-rdma/perftest#running-tests)

把固定提交的 `rccl-tests` 源码放到容器内 `/work/rccl-tests`。可从本仓库初始化子模块后同步，或从 [rccl-tests 固定提交](https://github.com/ROCm/rccl-tests/tree/40b1b17901370a7880d4a56854b5361c89f8d324) 取源码。首次构建用独立的 `build-mpi` 目录，避免复用单机构建的目标文件。可以在一端编译，再把产物复制到两端相同的绝对路径。

```bash
make -C /work/rccl-tests -j8 \
  BUILDDIR=/work/build-mpi ROCM_PATH=/opt/dtk GPU_TARGETS=gfx938 \
  "HIPCC=$(command -v hipcc)" "HIPIFY_PL_EXE=$(command -v hipify-perl)" \
  MPI=1 MPI_HOME=/opt/mpi

for test_bin in all_reduce_perf all_gather_perf alltoall_perf; do
  ldd "/work/build-mpi/$test_bin" | grep -E 'libmpi|librccl|not found'
  sha256sum "/work/build-mpi/$test_bin"
done
```

两端都要看到 `libmpi.so.40 => /opt/mpi/lib/...` 和 `librccl.so.1 => /opt/dtk/lib/...`，且无 `not found`。复制同一份产物时，两端 SHA256 应一致。

## 2. RoCEv2

### 2.1 确认端口和 GID

两端容器执行。确认所选 HCA 端口为 `PORT_ACTIVE`、`link_layer: Ethernet`，并从 `show_gids` 中选同时匹配本机 HCA、端口、RoCE IP、netdev 和 `v2` 的索引。把索引写回各自的 `/work/node.env`。两端索引可以不同。 [Mellanox RoCE GID 表说明](https://networking-docs.nvidia.com/doca/archive/3-4-0/rdma-over-converged-ethernet)

```bash
source /work/node.env
ibv_devinfo -d "$ROCE_HCA" -i "$ROCE_PORT"
ibdev2netdev
ip -br -4 addr show dev "$ROCE_IF"
ip route get "$PEER_ROCE_IP" from "$ROCE_IP"
show_gids
```

核对两端和交换路径的 VLAN、MTU，以及现场采用的 PFC/ECN 和优先级配置。两台都要使用所选 RoCE 端口的有效 GID。此镜像对应 RCCL 源码的 RoCE GID 默认值是 `0`，本流程明确传入每台机器查到的索引。 [镜像对应的 RCCL 源码备份](archives/README.md)

### 2.2 用 perftest 验证 RDMA

A 先启动服务端，B 再启动客户端。两端都先重新执行 `source /work/node.env`。B 的 `PEER_CTRL_IP` 指向 A，用于 perftest 的 TCP 握手；数据通过 `-d/-i/-x` 选定的 RoCE 口传输。

```bash
# A
ib_write_bw -d "$ROCE_HCA" -i "$ROCE_PORT" -x "$ROCE_GID" \
  -D 10 -s 65536 --report_gbits

# B
ib_write_bw -d "$ROCE_HCA" -i "$ROCE_PORT" -x "$ROCE_GID" \
  -D 10 -s 65536 --report_gbits "$PEER_CTRL_IP"
```

记录 `BW average` 和端口速率，再交换 A/B 的服务端与客户端角色复测另一方向。两向通过后，按第 4 节执行 `roce` 模式。

## 3. 原生 InfiniBand

### 3.1 确认端口和子网

两端容器执行。确认端口为 `PORT_ACTIVE`、`link_layer: InfiniBand`，检查 Base LID 和 SM LID 是否已分配。直连也需要子网管理器（SM）。有交换机或集群管理服务时，先确认已有的 SM 和分区配置。两端使用能互通的 IB 子网与 P_Key。 [InfiniBand Fabric Triage](https://networking-docs.nvidia.com/connnectxtriageguide/infiniband-fabric-triage)

```bash
source /work/node.env
ibv_devinfo -d "$IB_HCA" -i "$IB_PORT"
ibstat "$IB_HCA" "$IB_PORT"
grep -H . /sys/class/infiniband/"$IB_HCA"/ports/"$IB_PORT"/pkeys/*
```

### 3.2 用 perftest 验证 RDMA

A 先启动服务端，B 再启动客户端。这里使用默认 IB 分区，perftest 通过管理网握手，IB 数据通过 HCA 的原生 verbs 传输，因此 IB 口可以没有 IPoIB 地址。

```bash
# A
ib_write_bw -d "$IB_HCA" -i "$IB_PORT" -D 10 -s 65536 --report_gbits

# B
ib_write_bw -d "$IB_HCA" -i "$IB_PORT" -D 10 -s 65536 --report_gbits "$PEER_CTRL_IP"
```

记录 `BW average`，交换 A/B 角色复测。两向通过后，按第 4 节执行 `ib` 模式。本流程使用默认 P_Key；测试专用分区时，先确认两端对应的 P_Key 表索引。这版 RCCL 的 `NCCL_IB_PKEY` 接收的是**索引**。 [镜像对应的 RCCL 源码备份](archives/README.md)

## 4. 启动双机 RCCL

`mpirun` 直接运行 `rccl-tests` 的集合通信测试程序。三个程序分别调用 RCCL 的 [`ncclAllReduce`](../../rccl-tests/src/all_reduce.cu)、[`ncclAllGather`](../../rccl-tests/src/all_gather.cu) 和 [`ncclAllToAll`](../../rccl-tests/src/alltoall.cu)。

### 4.1 验证 MPI 双机启动

以下命令均在 A 容器执行。先加载 A 的节点配置。两台管理 IP 位于同一 IPv4 子网，`CTRL_CIDR` 填管理网实际 CIDR。MPI 使用 `ob1 + TCP` 走管理网，并关闭 MPI 自身的 HCOLL，便于单独观察 RCCL 数据面。

```bash
source /work/node.env
export ROCM_PATH=/opt/dtk
unset NCCL_IB_GID_INDEX NCCL_DEBUG_FILE
set -o pipefail
mkdir -p /work/logs

/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 2 -H "${CTRL_IP}:1,${PEER_CTRL_IP}:1" --map-by ppr:1:node \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /bin/hostname
```

预期各打印一次 `rccl-a` 和 `rccl-b`。随后的小规模 AllReduce 会进一步验证 `MPI_Init` 和数据通路。 [Open MPI 5.0.3 mpirun 参数](https://docs.open-mpi.org/en/v5.0.3/man-openmpi/man1/mpirun.1.html)

### 4.2 双机各 1 卡冒烟

每种网络先跑对应的 perftest。以下命令适用于两台机器的管理网接口名、所选 HCA 名和端口号相同，RoCE 还要求 GID **索引**相同。GID 的实际地址各用本机值。任一项不同就用第 4.4 节分节点传参。两种网络都指定 `NCCL_NET=IB`，所选后端无法使用时作业会报错。

**RoCEv2 · AllReduce · 8 B–64 MiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 2 -H "${CTRL_IP}:1,${PEER_CTRL_IP}:1" --map-by ppr:1:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$ROCE_HCA:$ROCE_PORT" \
  -x NCCL_IB_GID_INDEX="$ROCE_GID" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/all_reduce_perf -b 8 -e 64M -f 2 -d float -g 1 -c 1 \
  2>&1 | tee "/work/logs/roce-2rank.log"
```

**原生 IB · AllReduce · 8 B–64 MiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 2 -H "${CTRL_IP}:1,${PEER_CTRL_IP}:1" --map-by ppr:1:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$IB_HCA:$IB_PORT" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/all_reduce_perf -b 8 -e 64M -f 2 -d float -g 1 -c 1 \
  2>&1 | tee "/work/logs/ib-2rank.log"
```

检查两端各使用 1 张卡，按第 5 节验收后再扩到 16 卡。

### 4.3 双机 16 卡跑性能

每台 8 个 rank，每 rank 1 张 DCU。先用单个已验证的 HCA 端口建立基线。每条命令各跑三次，日志文件名区分网络、算子和时间。对比两种网络时保持包长、数据类型和迭代次数一致。

**RoCEv2 · AllReduce · 1 MiB–1 GiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 16 -H "${CTRL_IP}:8,${PEER_CTRL_IP}:8" --map-by ppr:8:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$ROCE_HCA:$ROCE_PORT" \
  -x NCCL_IB_GID_INDEX="$ROCE_GID" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/all_reduce_perf -b 1M -e 1G -f 2 -d float -g 1 -w 5 -n 20 -c 1 \
  2>&1 | tee "/work/logs/roce-16rank-allreduce-$(date +%Y%m%d-%H%M%S).log"
```

**RoCEv2 · AllGather · 1 MiB–1 GiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 16 -H "${CTRL_IP}:8,${PEER_CTRL_IP}:8" --map-by ppr:8:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$ROCE_HCA:$ROCE_PORT" \
  -x NCCL_IB_GID_INDEX="$ROCE_GID" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/all_gather_perf -b 1M -e 1G -f 2 -d float -g 1 -w 5 -n 20 -c 1 \
  2>&1 | tee "/work/logs/roce-16rank-allgather-$(date +%Y%m%d-%H%M%S).log"
```

**RoCEv2 · AllToAll · 1 MiB–1 GiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 16 -H "${CTRL_IP}:8,${PEER_CTRL_IP}:8" --map-by ppr:8:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$ROCE_HCA:$ROCE_PORT" \
  -x NCCL_IB_GID_INDEX="$ROCE_GID" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/alltoall_perf -b 1M -e 1G -f 2 -d float -g 1 -w 5 -n 20 -c 1 \
  2>&1 | tee "/work/logs/roce-16rank-alltoall-$(date +%Y%m%d-%H%M%S).log"
```

**原生 IB · AllReduce · 1 MiB–1 GiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 16 -H "${CTRL_IP}:8,${PEER_CTRL_IP}:8" --map-by ppr:8:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$IB_HCA:$IB_PORT" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/all_reduce_perf -b 1M -e 1G -f 2 -d float -g 1 -w 5 -n 20 -c 1 \
  2>&1 | tee "/work/logs/ib-16rank-allreduce-$(date +%Y%m%d-%H%M%S).log"
```

**原生 IB · AllGather · 1 MiB–1 GiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 16 -H "${CTRL_IP}:8,${PEER_CTRL_IP}:8" --map-by ppr:8:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$IB_HCA:$IB_PORT" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/all_gather_perf -b 1M -e 1G -f 2 -d float -g 1 -w 5 -n 20 -c 1 \
  2>&1 | tee "/work/logs/ib-16rank-allgather-$(date +%Y%m%d-%H%M%S).log"
```

**原生 IB · AllToAll · 1 MiB–1 GiB**

```bash
/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -np 16 -H "${CTRL_IP}:8,${PEER_CTRL_IP}:8" --map-by ppr:8:node \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$IB_HCA:$IB_PORT" \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  /work/build-mpi/alltoall_perf -b 1M -e 1G -f 2 -d float -g 1 -w 5 -n 20 -c 1 \
  2>&1 | tee "/work/logs/ib-16rank-alltoall-$(date +%Y%m%d-%H%M%S).log"
```

### 4.4 两端的接口名、HCA 或 GID 不同时

用一个 `mpirun`，在 `:` 前后分别写 A、B 的 `-H` 和 `-x`，两组 rank 进入同一个 MPI 作业。下面是双机各 1 卡的 RoCE AllReduce，`B_*` 换成 B 实测值。扩到 16 卡时把 `RANKS_PER_NODE` 改为 `8`，按第 4.3 节调整包长和迭代数，两侧使用同一个算子程序和同一组测试参数。测原生 IB 时，换成两端 IB HCA 和端口，删掉两处 `NCCL_IB_GID_INDEX` 参数。 [Open MPI 多应用启动语法](https://docs.open-mpi.org/en/v5.0.3/man-openmpi/man1/mpirun.1.html#synopsis)

```bash
B_CTRL_IF=eno1
B_ROCE_HCA=mlx5_2
B_ROCE_PORT=1
B_ROCE_GID=5
RANKS_PER_NODE=1
TEST=/work/build-mpi/all_reduce_perf

/opt/mpi/bin/mpirun --prefix /opt/mpi --stdin none --allow-run-as-root --bind-to none \
  --prtemca oob_tcp_if_include "$CTRL_CIDR" --prtemca plm_ssh_args "-p $SSH_PORT -o BatchMode=yes" \
  -np "$RANKS_PER_NODE" -H "${CTRL_IP}:${RANKS_PER_NODE}" \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$CTRL_IF" -x NCCL_IB_HCA="=$ROCE_HCA:$ROCE_PORT" -x NCCL_IB_GID_INDEX="$ROCE_GID" \
  "$TEST" -b 8 -e 64M -f 2 -d float -g 1 -c 1 \
  : -np "$RANKS_PER_NODE" -H "${PEER_CTRL_IP}:${RANKS_PER_NODE}" \
  --mca pml ob1 --mca btl self,sm,tcp --mca btl_tcp_if_include "$CTRL_CIDR" --mca coll '^hcoll' \
  -x ROCM_PATH -x LD_LIBRARY_PATH \
  -x NCCL_SOCKET_FAMILY=AF_INET -x NCCL_NET=IB -x NCCL_IB_DISABLE=0 -x NCCL_IB_PKEY=0 \
  -x NCCL_DEBUG=INFO -x NCCL_DEBUG_SUBSYS=INIT,NET,ENV \
  -x NCCL_SOCKET_IFNAME="=$B_CTRL_IF" -x NCCL_IB_HCA="=$B_ROCE_HCA:$B_ROCE_PORT" -x NCCL_IB_GID_INDEX="$B_ROCE_GID" \
  "$TEST" -b 8 -e 64M -f 2 -d float -g 1 -c 1 \
  2>&1 | tee "/work/logs/roce-per-node-$(date +%Y%m%d-%H%M%S).log"
```

## 5. 验收和排查

| 检查项 | 通过条件 |
| --- | --- |
| 端口和通道 | RoCE 日志中 `NET/IB : Using` 的目标 HCA 端口带 `/RoCE`，原生 IB 带 `/IB`。两种模式都要看到对应跨机 channel 的 `via NET/IB/...` |
| 正确性 | 进程正常退出，支持校验的各包长 `#wrong=0`，末尾 `Out of bounds values : 0 OK`。输出中的 `N/A` 单独记录 |
| GDRDMA | 检查跨机 channel 是否带 `/GDRDMA`，分别看 send 和 receive；只看到 `NET/IB` 只能确认 verbs 路径。 [GDRDMA 与回退路径](../transport/GDRDMA_vs_Fallback.md) |
| 带宽 | 对相同算子、包长和就地模式分别记录 `algbw`、`busbw`，以三轮中位数比较。perftest 的 `Gbit/s` 是单口主机内存测试，RCCL 的 `GB/s` 按集合操作口径报告。 [RCCL 带宽指标](../learning/rccl/PERFORMANCE.md) |

```bash
grep -E 'Using network|NET/IB : Using|via NET/|Out of bounds|WARN' \
  /work/logs/roce-2rank.log /work/logs/ib-2rank.log
```

需要进一步确认物理端口时，在两端测试前后读取目标 HCA 端口的 `counters/port_xmit_data` 和 `counters/port_rcv_data`。结合通道日志和计数器增量判断流量是否打到预期口。RoCE 低带宽时可同时查网卡和交换机的丢包、PFC、ECN 及重传计数。

| 现象 | 优先检查 |
| --- | --- |
| `hostname` 只出一台或无法启动远端 | 双向容器免密 SSH、`CTRL_CIDR`、SSH 与 PRRTE TCP 可达性、两端 `/opt/mpi` 路径 |
| `NET/IB : No device found` 或 `network IB not found` | 容器内 verbs 设备权限、HCA 与端口号、端口状态、`NCCL_IB_HCA` 的精确匹配 |
| RoCE 的 QP 修改失败或超时 | 先复跑指定 HCA 和 GID 的 `ib_write_bw`，检查 GID 类型、IP/VLAN、MTU 和交换配置 |
| IB 端口停在 `INIT` 或 verbs 超时 | 检查 SM、LID、交换路径和 P_Key |
| `ibv_reg_mr` 失败 | 核对容器内 `ulimit -l` 和宿主驱动。若 perftest 正常，再结合 RCCL 的 GDRDMA 日志排查 DCU 内存注册 |

已在目标镜像中核对工具版本、安装路径和 perftest 参数，并完成容器内 MPI 双 rank 冒烟。本文的双机 RoCE、IB 带宽和 GDRDMA 结果需在实际网络上采集。
