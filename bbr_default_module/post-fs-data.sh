#!/system/bin/sh
# BBRv3 默认算法 - 早期设置 (post-fs-data 阶段)
# 此时 vendor init 可能还未执行, 但仍写入, 作为第一道保险
# 部分设备在此阶段已可生效

MODDIR=${0%/*}

# 确认 BBRv3 可用 (内核已编译 CONFIG_TCP_CONG_BBR3=y)
if grep -q bbr3 /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    echo bbr3 > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    # BBR 推荐搭配 FQ 队列调度
    echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null
    # ECN 配合 BBRv3
    echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null
fi
