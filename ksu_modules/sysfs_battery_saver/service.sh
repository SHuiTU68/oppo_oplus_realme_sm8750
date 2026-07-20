#!/system/bin/sh
# Sysfs Battery Saver - 启动时通过 sysfs 调参降低功耗
# 零内核风险, 等效于 freeze_timeout patch 但不需要重编内核
# 配套 fastbuild_6.6.89_mtk.yml 的 battery_opt_enable / upstream_security_enable

MODDIR=${0%/*}
LOGFILE=/data/adb/sysfs_battery_saver.log

# 等待系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done
sleep 10

echo "[$(date '+%F %T')] sysfs_battery_saver 启动" > "$LOGFILE"

# 工具函数: 写入 sysfs 失败时记录但不中断
write_sysfs() {
    local path="$1"
    local value="$2"
    local desc="$3"
    if [ -w "$path" ]; then
        if echo "$value" > "$path" 2>/dev/null; then
            echo "[$(date '+%F %T')] [OK] $desc: $path = $value" >> "$LOGFILE"
        else
            echo "[$(date '+%F %T')] [FAIL] $desc: $path = $value (写入失败)" >> "$LOGFILE"
        fi
    else
        echo "[$(date '+%F %T')] [SKIP] $desc: $path (不存在或不可写)" >> "$LOGFILE"
    fi
}

# ============================================================
# 1. 用户空间进程冻结超时(关键: 加速息屏进入休眠)
#    上游默认 20000ms, 缩短为 5000ms
#    冻结失败的进程更快被判定为不可冻结, 不再长时间阻塞 suspend
# ============================================================
write_sysfs /sys/power/pm_freeze_timeout 5000 "用户空间冻结超时(20s->5s)"

# ============================================================
# 2. suspend 阻塞超时: /sys/power/pm_print_max_depth 不动
#    但 autosleep 延迟可通过 pm_wakeup_timer_activation
# ============================================================
# 此项无对应 sysfs, 跳过

# ============================================================
# 3. workqueue power-efficient 模式
#    内核 CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y 已生效
#    这里再显式写入确保启用
# ============================================================
write_sysfs /sys/module/workqueue/parameters/power_efficient Y "workqueue 省电模式"

# ============================================================
# 4. CPU 调度相关参数
# ============================================================
# Schedutil rate_limit(如可调)
for cpu in /sys/devices/system/cpu/cpu0/cpufreq; do
    if [ -d "$cpu" ]; then
        # schedutil 调速器的 rate_limit_us(如可调)
        for rl in "$cpu"/schedutil/rate_limit_us "$cpu"/cpufreq/schedutil/rate_limit_us; do
            if [ -w "$rl" ]; then
                write_sysfs "$rl" 2000 "schedutil rate_limit(2ms)"
                break
            fi
        done
    fi
done

# ============================================================
# 5. CPUidle governor: 启用 menu/ladder(若可切换)
# ============================================================
for gov in /sys/devices/system/cpu/cpuidle/current_governor /sys/devices/system/cpu/cpuidle/current_driver; do
    if [ -w "$gov" ]; then
        # 优先 menu governor(移动平台更省电)
        if grep -q menu "$gov" 2>/dev/null; then
            write_sysfs "$gov" menu "CPUidle governor"
        fi
    fi
done

# ============================================================
# 6. 内核脏页回写参数(减少 IO 唤醒频率)
# ============================================================
write_sysfs /proc/sys/vm/dirty_writeback_centisecs 1500 "脏页回写周期(15s)"
write_sysfs /proc/sys/vm/dirty_expire_centisecs 1500 "脏页过期(15s)"
write_sysfs /proc/sys/vm/swappiness 100 "swappiness(zram场景建议100)"
write_sysfs /proc/sys/vm/watermark_scale_factor 100 "水位缩放因子(更早回收)"

# ============================================================
# 7. 启用 laptop_mode(更积极聚合写入, 减少磁盘唤醒)
# ============================================================
write_sysfs /proc/sys/vm/laptop_mode 5 "laptop_mode(聚合写入)"

# ============================================================
# 8. 内核 panic/oops 后不自动重启(便于排查)
# ============================================================
write_sysfs /proc/sys/kernel/panic 0 "panic 不自动重启"
write_sysfs /proc/sys/kernel/panic_on_oops 0 "oops 不 panic"

# ============================================================
# 9. 减少 printk 唤醒(若可调)
# ============================================================
write_sysfs /proc/sys/kernel/printk_devkmsg off "屏蔽 devkmsg"

# ============================================================
# 10. 网络省电(若网卡支持)
# ============================================================
# WiFi iw 命令需要 root, 这里仅尝试 sysfs
for path in /sys/module/wlan/parameters/*; do
    case "$(basename "$path")" in
        *power*|*ps*|*suspend*)
            [ -w "$path" ] && write_sysfs "$path" Y "WiFi 省电: $(basename "$path")"
            ;;
    esac
done

echo "[$(date '+%F %T')] sysfs_battery_saver 完成" >> "$LOGFILE"
