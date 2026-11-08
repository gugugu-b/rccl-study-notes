# BW1100 安装 DTK 26.10 与运行 RCCL

## 1. 环境与前置检查

本文记录麒麟 V10 SP3 x86_64、内核 `4.19.90-89.11.v2401.ky10.x86_64`、单机 8 张 BW1100（`gfx938`）的实测流程。驱动使用 `rock-6.4.2-V2.1.0.run`，RCCL 动态库随 DTK 下载，`rccl-tests` 单独下载并编译。安装操作在 Linux 测试机的 Bash 中以 root 执行。

```bash
uname -r
grep -E '^(dist_id|arch)=' /etc/.kyinfo
rpm -q "kernel-devel-$(uname -r)" "kernel-headers-$(uname -r)" gcc gcc-c++ make cmake
lspci -Dnn -d 1d94:6430
df -h /opt /data4

grep -ow nomodeset /proc/cmdline || true
fuser -v /dev/kfd /dev/mkfd /dev/dri/renderD* 2>&1 || true
```

确认内核版本与安装包匹配，启动参数里没有 `nomodeset`，DCU 上的业务已退出。本机安装前只有 `hymgr` 占用 `/dev/mkfd`。升级前保存现有驱动版本、拓扑和 `/etc/hfm`、`/etc/hymgr` 配置。

## 2. 下载并校验安装包

```bash
dtk_work=/data4/dtk-26.10-setup
install -d -m 700 "$dtk_work"
cd "$dtk_work"

# 服务器需要代理时，按机器配置设置 https_proxy。
driver=rock-6.4.2-V2.1.0.run
toolkit=DTK-26.10-Kylinv10SP3-x86_64.tar.gz
driver_dir='https://download.sourcefind.cn:65024/file/6/DTK-%E9%A9%B1%E5%8A%A8/dtk-26.10%E9%A9%B1%E5%8A%A8'
toolkit_dir='https://download.sourcefind.cn:65024/file/1/DTK-26.10/Kylinv10SP3'

(
    set -eo pipefail
    download_checked() {
        local base_url=$1 package=$2 checksum
        curl -fLSs --retry 3 "$base_url/$package.md5" -o "$package.md5"
        curl -fLSs --retry 3 --connect-timeout 15 -C - \
            "$base_url/$package" -o "$package.part"
        checksum=$(awk 'NR == 1 { print $1 }' "$package.md5")
        [[ "$checksum" =~ ^[[:xdigit:]]{32}$ ]]
        printf '%s  %s\n' "$checksum" "$package.part" | md5sum -c -
        mv -- "$package.part" "$package"
    }

    download_checked "$driver_dir" "$driver"
    download_checked "$toolkit_dir" "$toolkit"
)
```

官方校验文件首行为哈希，后面有构建时间。上面的命令只取首行，两个包都通过校验后再安装。 [DTK 26.10 发布公告](https://developer.sourcefind.cn/category/dynamics/detail?post_id=96f215dc-bb04-11f1-b289-0242ac150003) · [官方下载目录](https://download.sourcefind.cn:65024/1/main/DTK-26.10)

## 3. 安装驱动

```bash
(
    set -eo pipefail
    cd /data4/dtk-26.10-setup
    chmod 700 rock-6.4.2-V2.1.0.run
    ./rock-6.4.2-V2.1.0.run -A 2>&1 | tee driver-install.log
)
```

`-A` 按安装器默认选项自动执行。本机安装器识别出 `OAM_7HSW_8HCU`，同时更新了 8 张卡的 VBIOS 和 7 个 HSW 的固件。等待安装器成功退出，再检查驱动与链路。

```bash
lsmod | awk '$1 ~ /^(hycu|hydcu|hsw)/'
systemctl is-active hfm hymgr
timeout -k 3s 15s /opt/hyhal/bin/hy-smi --showdriverversion
timeout -k 3s 15s /opt/hyhal/bin/hy-smi
timeout -k 3s 15s /opt/hyhal/bin/hy-smi --showcurrenthslstate |
    tee /data4/dtk-26.10-setup/hsl-state.log
grep -c 'link up' /data4/dtk-26.10-setup/hsl-state.log
```

本机在线加载后显示驱动 `6.4.2-V2.1.0`，`hfm` 和 `hymgr` 为 `active`，8 张卡为 `Normal`，共 56 条 HSL 链路为 `up`。本次验收覆盖在线加载后的启动轮次。按手册重启时，在重启后重新执行这些检查。 [DTK 安装部署手册第 3.9 节](https://download.sourcefind.cn:65024/file/1/DTK-26.10/Document/DTK%2026.10%20%E5%BC%80%E5%8F%91%E7%8E%AF%E5%A2%83%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2%E6%89%8B%E5%86%8C.pdf)

## 4. 安装 DTK 与确认 RCCL 库

以下命令用于新安装。已有 `/opt/dtk` 或 `/opt/dtk-26.10` 时，先确认当前指向及版本再切换。

```bash
(
    set -eo pipefail
    cd /data4/dtk-26.10-setup
    for path in /opt/dtk /opt/dtk-26.10; do
        [[ ! -e "$path" && ! -L "$path" ]]
    done

    stage=$(mktemp -d /opt/.dtk-26.10.XXXXXX)
    tar --no-same-owner -xzf DTK-26.10-Kylinv10SP3-x86_64.tar.gz -C "$stage"
    test -r "$stage/dtk-26.10/env.sh"
    test -r "$stage/dtk-26.10/lib/librccl.so"
    mv -T --no-clobber "$stage/dtk-26.10" /opt/dtk-26.10
    rmdir "$stage"
    ln -s /opt/dtk-26.10 /opt/dtk
)

source /opt/dtk/env.sh
cat /opt/dtk/.dtk_version
hipcc --version
timeout -k 3s 25s rocminfo > /data4/dtk-26.10-setup/rocminfo.log
awk '/^[[:space:]]*Name:[[:space:]]*gfx[0-9]/ {print $2}' \
    /data4/dtk-26.10-setup/rocminfo.log | sort | uniq -c
ls -l /opt/dtk/lib/librccl.so* /opt/dtk/include/rccl/rccl.h
```

本机的 `rocminfo` 返回 8 个 `gfx938`。DTK 包已经提供编译好的 `/opt/dtk/lib/librccl.so` 及头文件。发布公告写的是 RCCL 2.27.3，本次包里实际加载的是 **2.27.7-HEAD（`3b793e3`）**，以测试程序打印的版本及动态库路径为准。

## 5. 下载并编译 rccl-tests

使用本次验证过的提交 `40b1b17901370a7880d4a56854b5361c89f8d324`。

```bash
cd /data4/dtk-26.10-setup
git clone --branch develop_deprecated https://github.com/ROCm/rccl-tests.git
git -C rccl-tests checkout --detach 40b1b17901370a7880d4a56854b5361c89f8d324
```

如果测试机访问不了 GitHub，在工作区根目录用已有子模块导出源码，将压缩包传到测试机的 `/data4/dtk-26.10-setup/`。

```bash
# 工作区机器
git -C rccl-tests archive --format=tar.gz --prefix=rccl-tests/ \
    -o /tmp/rccl-tests-40b1b179.tar.gz 40b1b17901370a7880d4a56854b5361c89f8d324

# 压缩包传到测试机后执行
cd /data4/dtk-26.10-setup
tar -xzf rccl-tests-40b1b179.tar.gz
```

两种下载方式使用相同的编译命令。将 `GPU_TARGETS` 设为第 4 步实测的架构。

```bash
cd /data4/dtk-26.10-setup
source /opt/dtk/env.sh

make -C rccl-tests -j8 \
    "ROCM_PATH=$ROCM_PATH" \
    "HIPCC=$(command -v hipcc)" \
    "HIPIFY_PL_EXE=$(command -v hipify-perl)" \
    GPU_TARGETS=gfx938 \
    GIT_REV=40b1b179 GIT_BRANCH=develop_deprecated GIT_DIFF=

ldd rccl-tests/build/all_reduce_perf
ldd rccl-tests/build/alltoall_perf
```

两个可执行文件应解析到 `/opt/dtk/lib/librccl.so.1`，动态库列表中不能出现 `not found`。 [rccl-tests 源码](https://github.com/ROCm/rccl-tests/tree/40b1b17901370a7880d4a56854b5361c89f8d324)

## 6. 执行 AllReduce 与 AllToAll

先跑单卡和双卡小包，验证运行时及双卡通信。

```bash
cd /data4/dtk-26.10-setup/rccl-tests/build
source /opt/dtk/env.sh
set -o pipefail
mkdir -p ../../logs

timeout -k 8s 90s ./all_reduce_perf -b 64 -e 4M -f 2 -g 1
timeout -k 8s 90s ./all_reduce_perf -b 64 -e 16M -f 2 -g 2
```

两项小包测试都正常退出且校验通过后，在同一个目录运行 8 卡。以下命令保留原始参数，默认数据类型是 FP32。

```bash
timeout -k 8s 120s ./all_reduce_perf -b 1M -e 1G -f 2 -g 8 2>&1 |
    tee ../../logs/all_reduce_8gpu_1M-1G.log
timeout -k 8s 120s ./alltoall_perf -b 1M -e 1G -f 2 -g 8 2>&1 |
    tee ../../logs/alltoall_8gpu_1M-1G.log
```

验收时确认程序正常退出，日志打印预期 RCCL 版本、动态库路径和 8 张 BW1100。检查 `Out of bounds values : 0 OK`，再在 `size=1073741824` 那一行读两列 `busbw`。AllToAll 的 out-of-place 有 `#wrong=0`，in-place 显示 `#wrong=N/A`，该列仅作计时参考。 [AllToAll 测试源码](https://github.com/ROCm/rccl-tests/blob/40b1b17901370a7880d4a56854b5361c89f8d324/src/alltoall.cu)

## 7. 实测结果与调优

| 8 卡 FP32，1 GiB | Out-of-place BusBW | In-place BusBW |
| --- | ---: | ---: |
| AllReduce 默认 | 131.00 GB/s | 131.00 GB/s |
| AllToAll 默认 | 120.67 GB/s | 125.46 GB/s（计时） |

表中为默认参数下的三次中位数。各算子调优参数和校验范围见 [BW1100 调优复测](collectives/README.md#dtk-2610-调优复测)。同参数的版本对比见 [26.04.1 与 26.10 同机 A/B](DTK_26.04.1_vs_26.10_同机对照.md)。AllToAll 在 2–8 MiB 的 out-of-place 可以用下面的参数，三轮中位数提升约 7–8%，1 GiB 基本持平。

```bash
NCCL_P2P_LL_THRESHOLD=0 ./alltoall_perf -b 1M -e 1G -f 2 -g 8
```

遇到 `Attribute arch of node cpu not found` 时，可以用新路径重新探测拓扑后复测默认配置。本机跨 NUMA 重排 rank 时仍复现该错误，因此正式测试使用默认卡序。

```bash
RCCL_FORCE_DETECT_TOPO=1 \
RCCL_TOPO_FILE_NAME="$PWD/../../logs/topology-$(date +%s).xml" \
timeout -k 8s 120s ./alltoall_perf -b 1M -e 1G -f 2 -g 8
```

现场原始日志位于测试机的 `/data4/dtk2610-rccl.zSgNMd/`。驱动安装看 `driver-install.log`，基础验收看 `postinstall/`，FP32 扫包与 1 GiB 专项复测分别看 `fp32-sweep-tuning.22V4tw/` 和 `alltoall-1g-tuning.Cn25Ip/` 下的 `confirm.csv`。 [DTK 26.10 RCCL 使用手册](https://download.sourcefind.cn:65024/file/1/DTK-26.10/Document/DTK%2026.10%20RCCL%E5%BA%93%E4%BD%BF%E7%94%A8%E6%89%8B%E5%86%8C.pdf)
