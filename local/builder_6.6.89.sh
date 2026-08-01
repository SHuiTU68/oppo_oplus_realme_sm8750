#!/bin/bash
set -e

# ===== 获取脚本目录 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== 设置自定义参数 =====
echo "===== 欧加真SM8750通用6.6.89 A15 OKI内核本地编译脚本 By Coolapk@cctv18 ====="
echo ">>> 读取用户配置..."
MANIFEST=${MANIFEST:-oppo+oplus+realme}
read -p "请输入自定义内核后缀（默认：android15-8-g29d86c5fc9dd-abogki428889875-4k）: " CUSTOM_SUFFIX
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android15-8-g29d86c5fc9dd-abogki428889875-4k}
read -p "是否启用susfs？(y/n，默认：y; KSU分支选n时走pershoot dev-susfs hybrid hook, 应用传统SUSFS patch): " APPLY_SUSFS
APPLY_SUSFS=${APPLY_SUSFS:-y}
read -p "是否启用 KPM？(y-启用 KpatchNext独立kpm实现, n-关闭kpm，默认：n): " USE_PATCH_LINUX
USE_PATCH_LINUX=${USE_PATCH_LINUX:-n}
read -p "KSU分支版本(r=ReSukiSU, y=SukiSU Ultra, n=KernelSU Next(pershoot dev-susfs, hybrid hook: kprobe+SUSFS内核patch), k=KSU, x=XXKSU(backslashxx fork), w=KOWSU(KOWX712 fork), l=lkm模式(无内置KSU), 默认：r): " KSU_BRANCH
KSU_BRANCH=${KSU_BRANCH:-r}
read -p "是否应用 lz4 1.10.0 & zstd 1.5.7 补丁？(y/n，默认：y): " APPLY_LZ4
APPLY_LZ4=${APPLY_LZ4:-y}
read -p "是否应用 lz4kd 补丁？(y/n，默认：n): " APPLY_LZ4KD
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
read -p "是否启用网络功能增强优化配置？(y/n，默认：y): " APPLY_BETTERNET
APPLY_BETTERNET=${APPLY_BETTERNET:-y}
read -p "是否添加 BBRv3 等一系列拥塞控制算法？(y添加/n禁用/d默认，默认：n): " APPLY_BBR
APPLY_BBR=${APPLY_BBR:-n}
read -p "是否添加 Droidspaces 容器支持？(n禁用/s标准/e扩展，默认：n): " APPLY_DROIDSPACES
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
read -p "是否启用ADIOS调度器？(y/n，默认：y): " APPLY_ADIOS
APPLY_ADIOS=${APPLY_ADIOS:-y}
read -p "是否启用Re-Kernel？(y/n，默认：n): " APPLY_REKERNEL
APPLY_REKERNEL=${APPLY_REKERNEL:-n}
read -p "是否启用内核级基带保护？(y/n，默认：y): " APPLY_BBG
APPLY_BBG=${APPLY_BBG:-y}
read -p "是否启用NoMount挂载模块支持？(y/n，默认：n; 与ZeroMount互斥): " APPLY_NOMOUNT
APPLY_NOMOUNT=${APPLY_NOMOUNT:-n}
read -p "是否启用ZeroMount挂载模块支持？(VFS路径重定向+多策略回退VFS/OverlayFS/MagicMount+SUSFS集成+WebUI+bootloop guard; 需同时开启susfs; 与NoMount互斥,启用时自动跳过NoMount; y/n，默认：n): " APPLY_ZEROMOUNT
APPLY_ZEROMOUNT=${APPLY_ZEROMOUNT:-n}
read -p "是否启用上游安全+性能补丁？(8项: rtmutex GhostLock CVE-2026-43499/53163 + UFS timestamp quirk + mm/oom_kill反向遍历+thaw_process + mm/list_lru nokmem + crypto af_alg并发写 + arm64 uprobe nop模拟; dma-buf/tls/net/cpuidle已在6.6.89 OPPD合入,bpf因行号偏移fuzz改错位置编译错误已移除; y/n，默认：n): " APPLY_UPSTREAM
APPLY_UPSTREAM=${APPLY_UPSTREAM:-n}
read -p "是否启用 zram 魔改优化？(上游fix backport + CONFIG调优; 2项fix: write_partial UAF[6.6.142]+partial discard endio[6.6.140]; CONFIG: WRITEBACK+MULTI_COMP+TRACK_ENTRY_ACTIME,关MEMORY_TRACKING; 不干涉默认算法,保持OPPD原始lzo-rle; y/n，默认：n): " APPLY_ZRAM_OPT
APPLY_ZRAM_OPT=${APPLY_ZRAM_OPT:-n}

if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  KSU_TYPE="SukiSU Ultra"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  KSU_TYPE="ReSukiSU"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  KSU_TYPE="KernelSU Next (pershoot dev-susfs)"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  KSU_TYPE="KernelSU"
elif [[ "$KSU_BRANCH" == "x" || "$KSU_BRANCH" == "X" ]]; then
  KSU_TYPE="XXKSU"
elif [[ "$KSU_BRANCH" == "w" || "$KSU_BRANCH" == "W" ]]; then
  KSU_TYPE="KOWSU"
else
  KSU_TYPE="no KSU"
fi

echo
echo "===== 配置信息 ====="
echo "适用机型: $MANIFEST"
echo "自定义内核后缀: -$CUSTOM_SUFFIX"
echo "KSU分支版本: $KSU_TYPE"
echo "启用susfs: $APPLY_SUSFS"
echo "启用 KPM: $USE_PATCH_LINUX"
echo "应用 lz4&zstd 补丁: $APPLY_LZ4"
echo "应用 lz4kd 补丁: $APPLY_LZ4KD"
echo "应用网络功能增强优化配置: $APPLY_BETTERNET"
echo "应用 BBRv3 等算法: $APPLY_BBR"
echo "应用 Droidspaces 容器支持: $APPLY_DROIDSPACES"
echo "启用ADIOS调度器: $APPLY_ADIOS"
echo "启用Re-Kernel: $APPLY_REKERNEL"
echo "启用内核级基带保护: $APPLY_BBG"
echo "启用NoMount挂载模块: $APPLY_NOMOUNT"
echo "启用ZeroMount挂载模块: $APPLY_ZEROMOUNT"
echo "启用上游安全补丁: $APPLY_UPSTREAM"
echo "启用zram魔改优化: $APPLY_ZRAM_OPT"
echo "===================="
echo

# ===== 创建工作目录 =====
WORKDIR="$SCRIPT_DIR"
cd "$WORKDIR"

# ===== 安装构建依赖 =====
echo ">>> 安装构建依赖..."
# Function to run a command with sudo if not already root
SU() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

SU apt-mark hold firefox && apt-mark hold libc-bin && apt-mark hold man-db
SU rm -rf /var/lib/man-db/auto-update
SU apt-get update
SU apt-get install --no-install-recommends -y curl bison flex clang binutils dwarves git lld pahole zip perl make gcc python3 python-is-python3 bc libssl-dev libelf-dev cpio xz-utils tar unzip
SU rm -rf ./llvm.sh && wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh
SU ./llvm.sh 18 all

# ===== 初始化仓库 =====
echo ">>> 初始化仓库..."
rm -rf kernel_workspace
mkdir kernel_workspace
cd kernel_workspace
git clone --depth=1 https://github.com/cctv18/android_kernel_common_oneplus_sm8750 -b oneplus/sm8750_v_16.0.0_oneplus_13_6.6.89 common
echo ">>> 初始化仓库完成"

# ===== 清除 abi 文件、去除 -dirty 后缀 =====
echo ">>> 正在清除 ABI 文件及去除 dirty 后缀..."
rm common/android/abi_gki_protected_exports_* || true

for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done

# ===== 替换版本后缀 =====
echo ">>> 替换内核版本后缀..."
for f in ./common/scripts/setlocalversion; do
  sed -i "\$s|echo \"\\\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "$f"
done
sudo sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-'${CUSTOM_SUFFIX}'"/' ./common/arch/arm64/configs/gki_defconfig
sed -i 's/${scm_version}//' ./common/scripts/setlocalversion
echo "CONFIG_LOCALVERSION_AUTO=n" >> ./common/arch/arm64/configs/gki_defconfig

# ===== 拉取 KSU 并设置版本号 =====
if [[ $KSU_BRANCH == [yYrR] ]]; then
  echo ">>> 拉取 ReSukiSU 并设置版本（由于SukiSU长期未维护无法正常编译，且ReSukiSU兼容sukisu管理器，故SukiSU源码仓库已重定向为resukisu）..."
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s main
  echo 'CONFIG_KSU_FULL_NAME_FORMAT="%TAG_NAME%-%COMMIT_SHA%@cctv18"' >> ./common/arch/arm64/configs/gki_defconfig
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  echo ">>> 拉取 KernelSU Next (pershoot fork, dev-susfs 分支, hybrid hook) 并设置版本..."
  git clone --depth=1 -b "dev-susfs" https://github.com/pershoot/KernelSU-Next.git KernelSU-Next
  cd KernelSU-Next
  rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev-susfs&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" kernel/Kbuild
  KSU_COMMIT=$(curl -sL "https://api.github.com/repos/pershoot/KernelSU-Next/commits/dev-susfs" | grep -o '"sha": *"[^"]*"' | head -n 1 | sed 's/"sha": "//;s/"//' | cut -c1-7)
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := $KSU_COMMIT/g" kernel/Kbuild
  #手动集成 (复刻 setup.sh: symlink+Makefile+Kconfig; fork setup.sh 硬编码上游 OWNER 且 set -eu 在 git pull 失败时会中断)
  cd ..
  ln -sf ../../KernelSU-Next/kernel common/drivers/kernelsu
  grep -q 'kernelsu' common/drivers/Makefile || echo 'obj-$(CONFIG_KSU) += kernelsu/' >> common/drivers/Makefile
  grep -q 'drivers/kernelsu/Kconfig' common/drivers/Kconfig || sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' common/drivers/Kconfig
  cd common/drivers/kernelsu
  #为KernelSU Next添加WildKSU管理器支持
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/apk_sign.patch
  patch -p2 -N -F 3 < apk_sign.patch || true
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  echo "正在配置原版 KernelSU (tiann/KernelSU)..."
  curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
elif [[ "$KSU_BRANCH" == "x" || "$KSU_BRANCH" == "X" ]]; then
  echo "正在配置 XXKSU (backslashxx/KernelSU, tiann/KernelSU 的 fork, 使用 unity build + KSU_EXPECTED_SIZE/HASH 校验管理器签名)..."
  curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/refs/heads/master/kernel/setup.sh" | bash -s master
  cd ./KernelSU
  # 基于提交计数生成自定义版本号, 失败时使用 114514
  KSU_VERSION=$(expr $(git rev-list --count master) + 30000 2>/dev/null || echo 114514)
  # XXKSU 与原版 KSU 同源, Kbuild 沿用 DKSU_VERSION 字段；若上游改用其他字段则跳过(容错)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild || true
elif [[ "$KSU_BRANCH" == "w" || "$KSU_BRANCH" == "W" ]]; then
  echo "正在配置 KOWSU (KOWX712/KernelSU, tiann/KernelSU 的 fork)..."
  curl -LSs "https://raw.githubusercontent.com/KOWX712/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  # 基于提交计数生成自定义版本号, 失败时使用 114514
  KSU_VERSION=$(expr $(git rev-list --count main) + 30000 2>/dev/null || echo 114514)
  # KOWSU 与原版 KSU 同源, Kbuild 沿用 DKSU_VERSION 字段；若上游改用其他字段则跳过(容错)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild || true
else
  echo "已选择无内置KernelSU模式，跳过配置..."
fi

# ===== ZeroMount 依赖检查 (需要 SUSFS) =====
if [[ "$APPLY_ZEROMOUNT" == [yY] && "$APPLY_SUSFS" != [yY] ]]; then
  echo "ERROR: ZeroMount 依赖 SUSFS, 请同时开启 susfs 选项"
  exit 1
fi
if [[ "$APPLY_ZEROMOUNT" == [yY] && "$APPLY_NOMOUNT" == [yY] ]]; then
  echo "WARNING: NoMount 与 ZeroMount 互斥, 已自动跳过 NoMount (ZeroMount 优先)"
  APPLY_NOMOUNT=n
fi

# ===== 克隆补丁仓库&应用 SUSFS 补丁 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 应用 SUSFS&hook 补丁..."
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo ">>> 克隆补丁仓库..."
  git clone --depth=1 https://github.com/cctv18/susfs4oki.git susfs4ksu -b oki-android15-6.6
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./common
  patch -p1 < 50_add_susfs_in_gki-android15-6.6.patch || true
  patch -p1 -F 3 < 69_hide_stuff.patch || true
  cd ..
else
  echo ">>> 未开启susfs，跳过susfs补丁配置..."
fi
cd "$WORKDIR/kernel_workspace"
if [[ ( "$KSU_BRANCH" == [kK] || "$KSU_BRANCH" == [xX] || "$KSU_BRANCH" == [wW] ) && "$APPLY_SUSFS" == [yY] ]]; then
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  cd ./KernelSU
  patch -p1 < 10_enable_susfs_for_ksu.patch || true
fi
cd "$WORKDIR/kernel_workspace"

# ===== 应用 LZ4 & ZSTD 补丁 =====
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  echo ">>> 正在添加lz4 1.10.0 & zstd 1.5.7补丁..."
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8750.git
  cp ./oppo_oplus_realme_sm8750/other_patch/zram_patch/001-lz4.patch ./common/
  cp ./oppo_oplus_realme_sm8750/other_patch/zram_patch/001-lz4-clearMake.patch ./common/
  cp ./oppo_oplus_realme_sm8750/other_patch/zram_patch/lz4armv8.S ./common/lib
  cp ./oppo_oplus_realme_sm8750/other_patch/zram_patch/002-zstd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  git apply -p1 < 001-lz4.patch || true
  git apply -p1 < 001-lz4-clearMake.patch || true
  patch -p1 < 002-zstd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4&ZSTD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 应用 LZ4KD 补丁 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  echo ">>> 应用 LZ4KD 补丁..."
  if [ ! -d "SukiSU_patch" ]; then
    git clone --depth=1 https://github.com/ShirkNeko/SukiSU_patch.git
  fi
  cp -r ./SukiSU_patch/other/zram/lz4k/include/linux/* ./common/include/linux/
  cp -r ./SukiSU_patch/other/zram/lz4k/lib/* ./common/lib
  cp -r ./SukiSU_patch/other/zram/lz4k/crypto/* ./common/crypto
  cp ./SukiSU_patch/other/zram/zram_patch/6.6/lz4kd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  patch -p1 -F 3 < lz4kd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 添加 defconfig 配置项 =====
echo ">>> 添加 defconfig 配置项..."
DEFCONFIG_FILE=./common/arch/arm64/configs/gki_defconfig

# 写入通用 SUSFS/KSU 配置
echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  if [[ "$KSU_BRANCH" == [nN] ]]; then
    echo ">>> ksu_type=ksunext: 启用 fork 内建 hookless SUSFS 配置 (CONFIG_KSU_KPROBES_SUSFS=y)"
    echo ">>> 跳过传统 CONFIG_KSU_SUSFS_* 配置 (hookless 由 KSU 运行时实现, 无需内核 CONFIG)"
    # hookless SUSFS 依赖 KPROBES/KRETPROBES/HAVE_SYSCALL_TRACEPOINTS, hookless NoMount 依赖 KALLSYMS/NET/ARM64
    # 显式兜底开启这些依赖 (GKI 内核通常已开启, 但生产 defconfig 可能裁剪 KALLSYMS 节省体积)
    echo "CONFIG_KPROBES=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KRETPROBES=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KALLSYMS=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KALLSYMS_ALL=y" >> "$DEFCONFIG_FILE"
    # KSU hookless 三件套: HOOK + SUSFS + NOMOUNT
    # 选了 KSUN fork (susfs+nomount-hookless 分支) 就等于选择了 hookless nomount
    # fork 的 Kconfig 中 NOMOUNT 是 default y, 选这个 fork 就是冲着 nomount 来的
    # 只有用户选了 ZeroMount (互斥) 时才关闭 nomount
    echo "CONFIG_KSU_KPROBES_HOOK=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_KPROBES_SUSFS=y" >> "$DEFCONFIG_FILE"
    if [[ "$APPLY_ZEROMOUNT" == [yY] ]]; then
      echo "# CONFIG_KSU_KPROBES_NOMOUNT is not set" >> "$DEFCONFIG_FILE"
    else
      echo "CONFIG_KSU_KPROBES_NOMOUNT=y" >> "$DEFCONFIG_FILE"
    fi
  else
    echo ">>> 传统 SUSFS: 写入 CONFIG_KSU_SUSFS_* 配置"
    echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> "$DEFCONFIG_FILE"
  fi
else
  echo "CONFIG_KSU_SUSFS=n" >> "$DEFCONFIG_FILE"
fi
#添加对 Mountify (backslashxx/mountify) 模块的支持
echo "CONFIG_TMPFS_XATTR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$DEFCONFIG_FILE"

# 开启O2编译优化配置
echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> "$DEFCONFIG_FILE"
#跳过将uapi标准头安装到 usr/include 目录的不必要操作，节省编译时间
echo "CONFIG_HEADERS_INSTALL=n" >> "$DEFCONFIG_FILE"

# 仅在启用了 LZ4KD 补丁时添加相关算法支持
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_ZSMALLOC=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
EOF

fi

# ===== 启用网络功能增强优化配置 =====
if [[ "$APPLY_BETTERNET" == "y" || "$APPLY_BETTERNET" == "Y" ]]; then
  echo ">>> 正在启用网络功能增强优化配置..."
  echo "CONFIG_BPF_STREAM_PARSER=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_MAX=65534" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_PORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMARK=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTIP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_MAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETIFACE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_LIST_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_NAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_TARGET_MASQUERADE=y" >> "$DEFCONFIG_FILE"
  #由于部分机型的vintf兼容性检测规则，在开启CONFIG_IP6_NF_NAT后开机会出现"您的设备内部出现了问题。请联系您的设备制造商了解详情。"的提示，故添加一个配置修复补丁，在编译内核时隐藏CONFIG_IP6_NF_NAT=y但不影响对应功能编译
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/config.patch
  patch -p1 -F 3 < config.patch || true
  cd ..
fi

# ===== 添加 BBR 等一系列拥塞控制算法 =====
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" || "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
  echo ">>> 正在添加 BBR 等一系列拥塞控制算法..."
  # 应用 BBRv3 backport 补丁（来源：WildKernels/kernel_patches/common/bbrv3）
  # BBRv3 是 Google Linux 内核 6.4+ 引入的新一代拥塞控制算法，WildKernels 已 backport 到 android15-6.6 并保持 KABI 合规
  # 注：sysctl_add_proc_dou8vec_minmax / sysctl_fix_data-races 两个配套补丁在 6.6 内核中已合入，仅应用 bbrv3 主体补丁
  echo ">>> 应用 BBRv3 backport 补丁..."
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/bbrv3_patch/bbrv3_6.6.patch
  patch -p1 -F 3 < bbrv3_6.6.patch
  cd ..
  echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR3=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
  ################################################################################################################################
  # ★★★ 网络拥塞控制优化 (BBR 推荐搭配, 缺一不可) ★★★
  # FQ 队列调度 (CONFIG_NET_SCH_FQ): BBR pacing 通过 FQ 实现每流 pacing rate,
  #   若内核使用默认 sfq/pfifo 调度, BBR pacing 无法生效, 导致吞吐下降和 RTT 抖动.
  #   Google 官方文档明确建议: BBR 必须配合 FQ 队列使用.
  echo "CONFIG_NET_SCH_FQ=y" >> "$DEFCONFIG_FILE"
  # ECN 显式拥塞通知 (BBRv3 ECN 反馈支持): 路由器队列接近满时通过 IP/TCP 头标记拥塞而非丢包,
  #   BBRv3 根据 ECN 反馈调整发送速率, 减少尾丢包, 提升高 BDP 链路吞吐,
  #   同时降低 RTT 不公平性, 改善与 CUBIC 等基于丢包算法的共存公平性.
  echo "CONFIG_IP_ECN=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_ECN=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IPV6_ECN=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_NF_TARGET_ECN=y" >> "$DEFCONFIG_FILE"
  ################################################################################################################################
  if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
    echo "CONFIG_DEFAULT_BBR3=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_DEFAULT_TCP_CONG=bbr3" >> "$DEFCONFIG_FILE"
  else
    echo "CONFIG_DEFAULT_TCP_CONG=cubic" >> "$DEFCONFIG_FILE"
  fi
fi

# ===== 启用 Droidspaces 容器支持 =====
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  echo ">>> 正在添加 Droidspaces 容器支持..."
  # 开启 Droidspaces 容器所需内核支持
  echo "CONFIG_PID_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IPC_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_USER_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SYSVIPC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_DEVTMPFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NAMESPACES=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_POSIX_MQUEUE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_TARGET_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_RECENT=y" >> "$DEFCONFIG_FILE"
  # 开启 NTSync
  echo "CONFIG_NTSYNC=y" >> "$DEFCONFIG_FILE"
  cd common
  # 应用 Droidspaces 容器必须补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/droidspaces_patch/fix_sysvipc_kabi_6_7_8.patch
  patch -p1 -F 3 < fix_sysvipc_kabi_6_7_8.patch || true
  # 修补 oplus_bsp_midas 行为，避免开机崩溃
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/droidspaces_patch/fix_oplus_bsp_midas.patch
  patch -p1 -F 3 < fix_oplus_bsp_midas.patch || true
  # 应用 NTSync 补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/droidspaces_patch/ntsync_base.patch
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/droidspaces_patch/ntsync_compat_android15-6.6.patch
  patch -p1 -F 3 < ntsync_base.patch || true
  patch -p1 -F 3 < ntsync_compat_android15-6.6.patch || true
  cd ..
  if [[ "$APPLY_DROIDSPACES" == [eE] ]]; then
    echo "正在启用容器环境扩展支持..."
    # 开启虚拟 HCI 设备支持
    echo "CONFIG_BT_HCIVHCI=y" >> "$DEFCONFIG_FILE"
    # 开启 systemd-coredump 支持
    echo "CONFIG_STATIC_USERMODEHELPER=n" >> "$DEFCONFIG_FILE"
    # 添加 Lindroid EVDI DRM 驱动
    echo "CONFIG_DRM_LINDROID_EVDI=y" >> "$DEFCONFIG_FILE"
    cd common
    wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/droidspaces_patch/evdi_drm.patch
    patch -p1 -F 3 < evdi_drm.patch || true
    cd ..
  fi
fi

# ===== 启用ADIOS调度器 =====
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  echo ">>> 正在启用ADIOS调度器..."
  echo "CONFIG_MQ_IOSCHED_ADIOS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用Re-Kernel =====
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  echo ">>> 正在启用Re-Kernel..."
  echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用内核级基带保护 =====
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  echo ">>> 正在启用内核级基带保护..."
  echo "CONFIG_BBG=y" >> "$DEFCONFIG_FILE"
  cd ./common
  curl -sSL https://github.com/cctv18/Baseband-guard/raw/master/setup.sh | bash
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  cd ..
fi

# ===== 启用NoMount挂载模块支持 =====
if [[ "$APPLY_NOMOUNT" == "y" || "$APPLY_NOMOUNT" == "Y" ]]; then
  if [[ "$KSU_BRANCH" == [nN] ]]; then
    echo ">>> ksu_type=ksunext: NoMount 由 fork 内建 hookless 实现 (CONFIG_KSU_KPROBES_NOMOUNT), 跳过独立 nomount patch"
    echo ">>> hookless NoMount 内建于 drivers/kernelsu/ (非 fs/nomount.c), 已在 SUSFS 配置步骤中写入 CONFIG_KSU_KPROBES_NOMOUNT=y"
  else
    echo ">>> 正在启用NoMount挂载模块支持..."
    echo "CONFIG_NOMOUNT=y" >> "$DEFCONFIG_FILE"
    cd ./common
    wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/nomount_patch/kernel/src/nomount.c -O ./fs/nomount.c
    wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/nomount_patch/kernel/src/nomount.h -O ./fs/nomount.h
    wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/nomount_patch/kernel/patches/nomount_6.6_kernel_integration.patch
    patch -p1 -F 3 < nomount_6.6_kernel_integration.patch || true
    cd ..
  fi
fi

# ===== 启用ZeroMount挂载模块支持 (VFS路径重定向+多策略回退) =====
if [[ "$APPLY_ZEROMOUNT" == [yY] ]]; then
  echo ">>> 正在启用ZeroMount挂载模块支持(来自Enginex0/Super-Builders)..."
  cd ./common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/zeromount_patch/60_zeromount-android15-6.6.patch
  patch -p1 -F 3 --no-backup-if-mismatch < 60_zeromount-android15-6.6.patch
  # 验证 patch 应用成功 (检查所有被 zeromount patch 修改的文件)
  ZM_PATCH_ERRORS=0
  if ! grep -q 'obj-$(CONFIG_ZEROMOUNT).*zeromount' fs/Makefile; then
    echo "ERROR: zeromount patch: fs/Makefile 未包含 zeromount.o 编译规则"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'config ZEROMOUNT' fs/Kconfig; then
    echo "ERROR: zeromount patch: fs/Kconfig 未包含 config ZEROMOUNT"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if [[ ! -f fs/zeromount.c ]]; then
    echo "ERROR: zeromount patch: fs/zeromount.c 未创建"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if [[ ! -f include/linux/zeromount.h ]]; then
    echo "ERROR: zeromount patch: include/linux/zeromount.h 未创建"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'zeromount_get_static_vpath' fs/d_path.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/d_path.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'zeromount_getname_hook' fs/namei.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/namei.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'ZEROMOUNT_MAGIC_POS' fs/readdir.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/readdir.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'zeromount_stat_hook' fs/stat.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/stat.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'zeromount_spoof_statfs' fs/statfs.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/statfs.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'zeromount_spoof_xattr' fs/xattr.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/xattr.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'zeromount_spoof_mmap_metadata' fs/proc/task_mmu.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/proc/task_mmu.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if ! grep -q 'zeromount_should_skip' fs/proc/base.c 2>/dev/null; then
    echo "ERROR: zeromount patch: fs/proc/base.c 未包含 zeromount 钩子"
    ZM_PATCH_ERRORS=$((ZM_PATCH_ERRORS+1))
  fi
  if [[ $ZM_PATCH_ERRORS -gt 0 ]]; then
    echo "ERROR: zeromount patch 应用失败: $ZM_PATCH_ERRORS 项验证未通过, 请检查 SUSFS patch 是否先于 zeromount 正确应用"
    exit 1
  fi
  echo ">>> zeromount patch 验证通过: 全部 10 个文件均已正确修改"
  echo "CONFIG_ZEROMOUNT=y" >> ./arch/arm64/configs/gki_defconfig
  cd ..
fi

# ===== 启用上游安全补丁 (ACK android15-6.6-lts backport + linux-stable 6.6.140/6.6.144) =====
if [[ "$APPLY_UPSTREAM" == [yY] ]]; then
  echo ">>> 正在启用上游安全补丁..."
  cd ./common
  # [1/8] rtmutex GhostLock CVE-2026-43499: 修复优先级继承链 remove_waiter() 中的悬空指针 UAF
  echo ">>> [1/8] rtmutex GhostLock CVE-2026-43499..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/rtmutex_ghostlock_cve-2026-43499.patch
  patch -p1 --forward -F 3 < rtmutex_ghostlock_cve-2026-43499.patch || echo "warning: CVE-2026-43499 patch 应用失败,可能已合入"
  # [2/8] rtmutex CVE-2026-53163: syzbot 报告的 NULL-ptr-deref (CVE-2026-43499 后续)
  echo ">>> [2/8] rtmutex CVE-2026-53163 (后续修复)..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/rtmutex_cve-2026-53163.patch
  patch -p1 --forward -F 3 < rtmutex_cve-2026-53163.patch || echo "warning: CVE-2026-53163 patch 应用失败,可能已合入"
  # [3/8] UFS: 部分 Kioxia UFS 4 设备不支持 qTimestamp 属性, 添加 quirk 跳过避免错误日志
  echo ">>> [3/8] UFS no timestamp quirk..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/ufs_no_timestamp_quirk.patch
  patch -p1 --forward -F 3 < ufs_no_timestamp_quirk.patch || echo "warning: UFS timestamp quirk patch 应用失败,可能已合入或上下文不匹配"
  # [4/8] mm/oom_kill: OOM reaper 反向遍历 VMA maple tree, 减少 page table lock 竞争
  echo ">>> [4/8] mm/oom_kill OOM reaper 反向遍历..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/mm_oom_reap_reverse.patch
  patch -p1 --forward -F 3 < mm_oom_reap_reverse.patch || echo "warning: mm/oom_kill reap reverse patch 应用失败,可能已合入或上下文不匹配"
  # [5/8] mm/oom_kill: 引入 thaw_process() 解冻整个 OOM victim 进程(而非单线程)
  echo ">>> [5/8] mm/oom_kill thaw 整个 OOM victim..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/mm_oom_thaw_process.patch
  patch -p1 --forward -F 3 < mm_oom_thaw_process.patch || echo "warning: mm/oom_kill thaw process patch 应用失败,可能已合入或上下文不匹配"
  # [6/8] mm/list_lru: cgroup.memory=nokmem 时禁用 memcg_aware, 减少不必要的 memcg 操作
  echo ">>> [6/8] mm/list_lru nokmem 禁用 memcg_aware..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/mm_list_lru_nokmem.patch
  patch -p1 --forward -F 3 < mm_list_lru_nokmem.patch || echo "warning: mm/list_lru nokmem patch 应用失败,可能已合入或上下文不匹配"
  # [7/8] crypto: af_alg_sendmsg 禁止并发写, 修复 socket 内部状态不一致
  echo ">>> [7/8] crypto af_alg 禁止并发写..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/crypto_af_alg_concurrent_write.patch
  patch -p1 --forward -F 3 < crypto_af_alg_concurrent_write.patch || echo "warning: crypto af_alg concurrent write patch 应用失败,可能已合入或上下文不匹配"
  # [8/8] arm64: uprobe 模拟 nop 指令, 避免返回用户态执行, 提升 uprobe/uretprobe 性能
  echo ">>> [8/8] arm64 uprobe nop 模拟..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/arm64_uprobe_nop_simulate.patch
  patch -p1 --forward -F 3 < arm64_uprobe_nop_simulate.patch || echo "warning: arm64 uprobe nop simulate patch 应用失败,可能已合入或上下文不匹配"
  cd ..
fi

# ===== 启用 zram 魔改优化 (上游 fix backport + CONFIG 调优) =====
if [[ "$APPLY_ZRAM_OPT" == [yY] ]]; then
  echo ">>> 正在启用 zram 魔改优化(上游 fix backport + CONFIG 调优)..."
  cd ./common
  # [1/2] zram_bvec_write_partial UAF: zram_read_page 误传 bio 触发异步 endio (6.6.142)
  echo ">>> [1/2] zram fix write_partial UAF (6.6.142)..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/zram_fix_write_partial_uaf.patch
  patch -p1 --forward -F 3 < zram_fix_write_partial_uaf.patch || echo "warning: zram write_partial UAF patch 应用失败,可能已合入或上下文不匹配"
  # [2/2] zram_bio_discard: partial discard 路径遗漏 bio_endio (6.6.140)
  echo ">>> [2/2] zram fix partial discard endio (6.6.140)..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/upstream_patch/zram_fix_discard_endio.patch
  patch -p1 --forward -F 3 < zram_fix_discard_endio.patch || echo "warning: zram discard endio patch 应用失败,可能已合入或上下文不匹配"
  # CONFIG 调优 (不干涉默认算法, 保持 OPPD 原始 lzo-rle)
  echo ">>> 追加 zram CONFIG 调优到 gki_defconfig..."
  cat >> ./arch/arm64/configs/gki_defconfig << 'ZRAM_CFG_EOF'
# zram 魔改优化 CONFIG (不干涉默认算法, 保持 OPPD 原始 lzo-rle)
CONFIG_ZRAM_WRITEBACK=y
CONFIG_ZRAM_TRACK_ENTRY_ACTIME=y
CONFIG_ZRAM_MULTI_COMP=y
# CONFIG_ZRAM_MEMORY_TRACKING is not set
ZRAM_CFG_EOF
  echo "zram CONFIG 调优已追加 (WRITEBACK + MULTI_COMP + 关 MEMORY_TRACKING, 不改默认算法)"
  cd ..
fi

# ===== 禁用 defconfig 检查 =====
echo ">>> 禁用 defconfig 检查..."
sed -i 's/check_defconfig//' ./common/build.config.gki

# ===== 编译内核 =====
echo ">>> 开始编译内核..."
cd common
make -j$(nproc --all) LLVM=-18 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnuabeihf- CC=clang LD=ld.lld HOSTCC=clang HOSTLD=ld.lld O=out KCFLAGS+=-O2 KCFLAGS+=-Wno-error gki_defconfig all
echo ">>> 内核编译成功！"

# ===== 选择使用 patch_linux (KPM补丁)=====
OUT_DIR="$WORKDIR/kernel_workspace/common/out/arch/arm64/boot"
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  echo ">>> 使用 kptools-linux 工具处理输出..."
  cd "$OUT_DIR"
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kptools-linux
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kpimg-linux
  chmod +x ./kptools-linux
  ./kptools-linux -p -i ./Image -k ./kpimg-linux -o ./oImage
  rm -f Image
  mv oImage Image
  echo ">>> 已成功打上KP-N补丁!"
fi

# ===== 克隆并打包 AnyKernel3 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 克隆 AnyKernel3 项目..."
git clone https://github.com/cctv18/AnyKernel3 --depth=1

echo ">>> 清理 AnyKernel3 Git 信息..."
rm -rf ./AnyKernel3/.git

echo ">>> 拷贝内核镜像到 AnyKernel3 目录..."
cp "$OUT_DIR/Image" ./AnyKernel3/

echo ">>> 进入 AnyKernel3 目录并打包 zip..."
cd "$WORKDIR/kernel_workspace/AnyKernel3"

# ===== 如果启用 lz4kd，则下载 zram.zip 并放入当前目录 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  wget https://raw.githubusercontent.com/cctv18/oppo_oplus_realme_sm8750/refs/heads/main/zram.zip
fi

if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  wget https://github.com/cctv18/KPatch-Next/releases/latest/download/kpn.zip
fi

# ===== 生成 ZIP 文件名 =====
ZIP_NAME="Anykernel3-${MANIFEST}"

if [[ "$APPLY_SUSFS" == "y" || "$APPLY_SUSFS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-susfs"
fi
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4kd"
fi
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4-zstd"
fi
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  ZIP_NAME="${ZIP_NAME}-kpm"
fi
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbrv3"
fi
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  ZIP_NAME="${ZIP_NAME}-dss"
fi
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-adios"
fi
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-rek"
fi
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbg"
fi
if [[ "$APPLY_NOMOUNT" == "y" || "$APPLY_NOMOUNT" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-nomount"
fi
if [[ "$APPLY_ZEROMOUNT" == "y" || "$APPLY_ZEROMOUNT" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-zeromount"
fi
if [[ "$APPLY_UPSTREAM" == "y" || "$APPLY_UPSTREAM" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-usec"
fi
if [[ "$APPLY_ZRAM_OPT" == "y" || "$APPLY_ZRAM_OPT" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-zram"
fi

ZIP_NAME="${ZIP_NAME}-v$(date +%Y%m%d).zip"

# ===== 打包 ZIP 文件，包括 zram.zip（如果存在） =====
echo ">>> 打包文件: $ZIP_NAME"
zip -r "../$ZIP_NAME" ./*

ZIP_PATH="$(realpath "../$ZIP_NAME")"
echo ">>> 打包完成 文件所在目录: $ZIP_PATH"

# ===== 编译 nm 工具并打包 NoMount KSU 模块（如果启用 NoMount） =====
if [[ "$APPLY_NOMOUNT" == "y" || "$APPLY_NOMOUNT" == "Y" ]]; then
  echo ">>> 编译 nm userspace 工具（aarch64 freestanding）..."
  cd "$WORKDIR/kernel_workspace"
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/nomount_patch/userspace/src/nm.c -O ./nm.c
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/nomount_patch/userspace/src/nm.h -O ./nm.h
  clang --target=aarch64-linux-gnu -static -nostdlib -O2 -ffreestanding -fno-stack-protector -fuse-ld=lld -o ./nm ./nm.c
  file ./nm
  ls -la ./nm

  echo ">>> 复制官方 NoMount 模块模板（含 WebUI）..."
  # 本地仓库就在 $WORKDIR，直接 cp 整个 module 目录
  cp -r "$WORKDIR/other_patch/nomount_patch/module" ./nomount_module
  mkdir -p nomount_module/bin

  # 把编译好的 nm 二进制放到 bin/nm-arm64（官方 customize.sh 会自动 rename 为 nm）
  cp ./nm nomount_module/bin/nm-arm64
  chmod 755 nomount_module/bin/nm-arm64
  # 设置脚本文件权限
  chmod 755 nomount_module/customize.sh nomount_module/metainstall.sh nomount_module/metamount.sh nomount_module/service.sh

  echo ">>> 打包 NoMount KSU 模块 zip..."
  cd nomount_module
  NOMOUNT_ZIP_NAME="NoMount_v1.1.0_aarch64.zip"
  zip -r "../$NOMOUNT_ZIP_NAME" ./*
  cd ..
  echo ">>> NoMount 模块打包完成: $(realpath $NOMOUNT_ZIP_NAME)"

  # 清理编译中间产物
  rm -f ./nm.c ./nm.h ./nm
fi
