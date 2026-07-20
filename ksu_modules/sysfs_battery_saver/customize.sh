#!/system/bin/sh
# KSU 模块安装脚本
# 仅检查架构

ARCH=$(getprop ro.product.cpu.abi)
case "$ARCH" in
    arm64-v8a)
        ;;
    *)
        ui_print "仅支持 arm64-v8a 架构"
        ui_print "当前架构: $ARCH"
        abort "不兼容的架构"
        ;;
esac

ui_print "- Sysfs Battery Saver 模块安装"
ui_print "- 详见 /data/adb/sysfs_battery_saver.log"
