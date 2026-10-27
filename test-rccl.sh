#!/bin/bash
set -eo pipefail

BUILD_DIR="/workspace/rccl-tests-master/build"
LOG_DIR="logs"
CARD_NUMS=(8)

# 获取所有包含 perf 的测试程序
OPERATIONS=$(ls "$BUILD_DIR" | grep -i perf)
mkdir -p "$LOG_DIR"/{single_test,double_test}

double_test() {
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
                "$BUILD_DIR/$oper" -b 2 -e 2G -f 2 -g 1 2>&1 | tee -a "$log_file"
        done
    done
}

single_test() {
    for oper in $OPERATIONS; do
        for card in "${CARD_NUMS[@]}"; do
            (( card <= 1 )) && continue
            local log_file="$LOG_DIR/single_test/${oper}_${card}cards.log"

            echo -e "\e[33m================ 执行 $oper 的 $card 卡单机测试 ==================\e[0m"
            "$BUILD_DIR/$oper" -b 2 -e 1G -f 2 -g "$card" 2>&1 | tee -a "$log_file"
        done
    done
}

# 默认执行 single_test，也可通过 ./script.sh double_test 切换
"${1:-single_test}"
