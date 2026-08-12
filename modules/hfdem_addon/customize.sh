#!/system/bin/sh
SKIPUNZIP=0

ui_print " "
ui_print "|=================================="
ui_print "| hfdem附加模块 v1.0.2"
ui_print "| 作者：Jiuxia"
ui_print "| 感谢 @温柔浩：原模块基础"
ui_print "| 感谢 @Amktiao：5.15 内核优化（内核已内建）"
ui_print "|=================================="
ui_print " "

# 只清理本模块同 ID 的旧目录，不引用、不触碰 Dynamic OC。
OLD_MOD="/data/adb/modules/hfdem_savemode"
if [ "$OLD_MOD" != "$MODPATH" ] && [ -d "$OLD_MOD" ]; then
    ui_print "- 清除本模块旧版本残留..."
    rm -rf "$OLD_MOD"
fi


ui_print "- 本模块不携带第三方 KO，优化全部通过 sysfs/系统属性生效"
ui_print "- 动态调频监听由独立超频模块负责；本模块不执行 CPU/GPU/总线频率写入"
rm -f "$MODPATH/gpu_boost.conf"
set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in service.sh utils.sh uninstall.sh no_oc_check.sh; do
    [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
done
ui_print "- 安装完成，重启生效"
