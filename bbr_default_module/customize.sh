#!/system/bin/sh
# BBRv3 默认算法模块 - 安装脚本
SKIPUNZIP=0

ui_print ""
ui_print "==========================================="
ui_print "  BBRv3 默认拥塞算法强制覆盖"
ui_print "==========================================="
ui_print "  覆盖 OPPO vendor init 的 bic 硬编码"
ui_print "  三重保险: post-fs-data + service + prop"
ui_print "==========================================="
ui_print ""

# 检查内核是否支持 BBRv3
if grep -q bbr3 /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    ui_print "  [OK] 内核已编译 BBRv3 支持"
    ui_print "  当前可用: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control)"
else
    ui_print "  [警告] 内核未检测到 BBRv3, 请确认:"
    ui_print "    - 已刷入含 BBRv3 patch 的内核"
    ui_print "    - 内核配置已启用 CONFIG_TCP_CONG_BBR3=y"
    ui_print "  模块仍会安装, 但 BBRv3 可能无法生效"
fi

ui_print ""
ui_print "  安装完成后重启即可生效"
ui_print "  重启后可用以下命令验证:"
ui_print "    cat /proc/sys/net/ipv4/tcp_congestion_control"
ui_print "    (应显示 bbr3, 而非 bic)"
ui_print ""

set_perm_recursive "$MODPATH" 0 0 0755 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
