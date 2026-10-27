#!/bin/bash

BUILD_DIR="${BUILD_DIR:-/workspace/rccl-tests-master/build}"
LOG_DIR="${LOG_DIR:-logs}"
CSV_FILE="${CSV_FILE:-rccl_perf_summary.csv}"
CARD_NUMS=(8)

# 构建目录校验：不存在时直接退出，避免跑出一份空统计还显示"测试完成"
if [[ ! -d "$BUILD_DIR" ]]; then
    echo -e "\e[31m[错误] 构建目录不存在: $BUILD_DIR\e[0m" >&2
    exit 1
fi

# 获取 DTK 版本（去除换行）
DTK_VERSION=$(cat /opt/dtk/.dtk_version 2>/dev/null | tr -d '\r\n')
DTK_VERSION=${DTK_VERSION:-"Unknown"}

# 获取所有 perf 测试程序（包含 hypercube）
OPERATIONS=$(ls "$BUILD_DIR" | grep -i perf)
if [[ -z "$OPERATIONS" ]]; then
    echo -e "\e[31m[错误] $BUILD_DIR 下未找到任何 *perf 测试程序\e[0m" >&2
    exit 1
fi
mkdir -p "$LOG_DIR"/{single_test,double_test}

# 初始化 CSV 表头（若文件不存在）
[ ! -f "$CSV_FILE" ] && echo "算子类型,测试模式,卡数,数据包大小,In-Place_BusBW(GB/s),DTK版本" > "$CSV_FILE"

# 提取最后一个包的 in-place busbw 并写入 CSV
record_result() {
    local oper=$1 mode=$2 card=$3 max_size=$4 log_file=$5
    local busbw=$(grep -E '^[[:space:]]*[0-9]+' "$log_file" | tail -n 1 | awk '{print $(NF-1)}')
    # 取到非数值（表格行被日志干扰）时记 N/A，避免污染统计
    [[ "$busbw" =~ ^[0-9]+(\.[0-9]+)?$ ]] || busbw="N/A"
    echo "$oper,$mode,$card,$max_size,$busbw,$DTK_VERSION" >> "$CSV_FILE"
    echo -e "\e[32m[已记录] $oper | $mode | $card 卡 | in-place busbw: ${busbw} GB/s\e[0m"
}

# 双机测试：跑所有算子（包含 hypercube_perf）
double_test() {
    local max_size="2G"
    for oper in $OPERATIONS; do
        for card in "${CARD_NUMS[@]}"; do
            local total_procs=$((card * 2))
            local log_file="$LOG_DIR/double_test/${oper}_${card}cards.log"

            echo -e "\e[33m================ 执行 $oper 的 $card 卡双机测试 ==================\e[0m"
            mpirun -np "$total_procs" \
                -H "node1:$card,node2:$card" \
                --mca btl_tcp_if_include ens22np0 \
                --mca plm_rsh_args "-p 1234" \
                -x ROCM_PATH -x LD_LIBRARY_PATH \
                -x NCCL_DEBUG=INFO \
                -x NCCL_IB_DISABLE=0 \
                -x NCCL_IB_HCA=mlx5_1,mlx5_2,mlx5_3,mlx5_6 \
                -x NCCL_SOCKET_IFNAME=ens22np0 \
                -x NCCL_IB_GID_INDEX=3 \
                -x NCCL_NET_GDR_READ=1 \
                -x NCCL_PXN_DISABLE=0 \
                "$BUILD_DIR/$oper" -b 2 -e "$max_size" -f 2 -g 1 2>&1 | tee "$log_file"

            record_result "$oper" "双机" "$total_procs" "$max_size" "$log_file"
        done
    done
}

# 单机测试：单独跳过 hypercube_perf
single_test() {
    local max_size="1G"
    for oper in $OPERATIONS; do
        [[ "$oper" =~ hypercube ]] && continue
        for card in "${CARD_NUMS[@]}"; do
            (( card <= 1 )) && continue
            local log_file="$LOG_DIR/single_test/${oper}_${card}cards.log"

            echo -e "\e[33m================ 执行 $oper 的 $card 卡单机测试 ==================\e[0m"
            "$BUILD_DIR/$oper" -b 2 -e "$max_size" -f 2 -g "$card" 2>&1 | tee "$log_file"

            record_result "$oper" "单机" "$card" "$max_size" "$log_file"
        done
    done
}

# 默认执行 single_test，也可通过 ./run-rccl-perf-suite.sh double_test 执行双机
"${1:-single_test}"

echo -e "\n\e[36m测试完成！统计数据已写入: $CSV_FILE\e[0m"
