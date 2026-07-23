#!/system/bin/sh
# BBR 默认算法 - 开机后最终覆盖 (service.sh 在 on boot 之后执行)
# OPPO vendor/etc/init/networksetting.rc 在此之前已执行 write ... bic
# 这里是最后且最可靠的一道保险, 确保覆盖 vendor 的 bic 硬编码

MODDIR=${0%/*}

# 等待 sysctl 节点就绪
until [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; do
    sleep 1
done

# 确认 BBR 可用
if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    # 延迟 3s 确保 vendor init.networksetting.rc 已执行完毕
    sleep 3
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null
    echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null

    # 写入日志 (供调试)
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BBR default applied"
        echo "  congestion_control: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
        echo "  default_qdisc: $(cat /proc/sys/net/core/default_qdisc)"
        echo "  tcp_ecn: $(cat /proc/sys/net/ipv4/tcp_ecn)"
        echo "  available: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control)"
    } > /data/adb/bbr_default.log 2>/dev/null
fi
