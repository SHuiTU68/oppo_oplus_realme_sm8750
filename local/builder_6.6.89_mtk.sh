#!/bin/bash
set -e

# ===== 获取脚本目录 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== 设置自定义参数 =====
echo "===== 欧加真MT6991通用6.6.89 A15 OKI内核本地编译脚本 By Coolapk@cctv18 ====="
echo ">>> 读取用户配置..."
MANIFEST=${MANIFEST:-oppo+oplus+realme}
read -p "请输入自定义内核后缀（默认：android15-8-g29d86c5fc9dd-abogki428889875-4k）: " CUSTOM_SUFFIX
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android15-8-g29d86c5fc9dd-abogki428889875-4k}
read -p "是否启用susfs？(y/n，默认：y): " APPLY_SUSFS
APPLY_SUSFS=${APPLY_SUSFS:-y}
read -p "是否启用 KPM？(y-启用 KpatchNext独立kpm实现, n-关闭kpm，默认：n): " USE_PATCH_LINUX
USE_PATCH_LINUX=${USE_PATCH_LINUX:-n}
read -p "KSU分支版本(r=ReSukiSU, y=SukiSU Ultra, n=KernelSU Next, k=KSU, x=XXKSU(backslashxx fork), l=lkm模式(无内置KSU), 默认：r): " KSU_BRANCH
KSU_BRANCH=${KSU_BRANCH:-r}
read -p "是否应用 lz4 1.10.0 & zstd 1.5.7 补丁？(y/n，默认：y): " APPLY_LZ4
APPLY_LZ4=${APPLY_LZ4:-y}
read -p "是否应用 lz4kd 补丁？(y/n，默认：n): " APPLY_LZ4KD
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
read -p "是否启用网络功能增强优化配置？(y/n，默认：n): " APPLY_BETTERNET
APPLY_BETTERNET=${APPLY_BETTERNET:-n}
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
read -p "是否启用NoMount挂载模块支持？(y/n，默认：n): " APPLY_NOMOUNT
APPLY_NOMOUNT=${APPLY_NOMOUNT:-n}
read -p "是否启用zstdp压缩算法？(zstd preSplit变种,移植自hubai7285-code/ABK,与lz4/zstd补丁平行;y/n，默认：n): " APPLY_ZSTDP
APPLY_ZSTDP=${APPLY_ZSTDP:-n}
read -p "是否启用省电优化？(Log Silencing+Wakelock hard-caps+Schedutil rate-limit+省电CONFIG,低风险组合;y/n，默认：n): " APPLY_BATOPT
APPLY_BATOPT=${APPLY_BATOPT:-n}
read -p "是否启用上游安全+性能补丁？(13项: rtmutex CVE + dma-buf + UFS + mm/oom_kill + mm/list_lru + bpf + tls + net + crypto + arm64 + cpuidle; y/n，默认：n): " APPLY_UPSTREAM
APPLY_UPSTREAM=${APPLY_UPSTREAM:-n}

if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  KSU_TYPE="SukiSU Ultra"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  KSU_TYPE="ReSukiSU"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  KSU_TYPE="KernelSU Next"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  KSU_TYPE="KernelSU"
elif [[ "$KSU_BRANCH" == "x" || "$KSU_BRANCH" == "X" ]]; then
  KSU_TYPE="XXKSU"
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
echo "启用zstdp压缩算法: $APPLY_ZSTDP"
echo "启用省电优化: $APPLY_BATOPT"
echo "启用上游安全补丁: $APPLY_UPSTREAM"
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
git clone --depth=1 https://github.com/cctv18/android_kernel_oneplus_mt6991 -b oneplus/mt6991_v_15.0.2_ace5_ultra_6.6.89 common
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
  echo ">>> 拉取 KernelSU Next 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
  cd KernelSU-Next
  rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" kernel/Kbuild
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := $KSU_GIT_TAG/g" kernel/Kbuild
  #为KernelSU Next添加WildKSU管理器支持
  cd ../common/drivers/kernelsu
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
else
  echo "已选择无内置KernelSU模式，跳过配置..."
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
else
  echo ">>> 未开启susfs，跳过susfs补丁配置..."
fi
cd "$WORKDIR/kernel_workspace"
if [[ ( "$KSU_BRANCH" == [kK] || "$KSU_BRANCH" == [xX] ) && "$APPLY_SUSFS" == [yY] ]]; then
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  cd ./KernelSU
  patch -p1 < 10_enable_susfs_for_ksu.patch || true
fi
cd "$WORKDIR/kernel_workspace"

# ===== 应用 LZ4 & ZSTD 补丁 =====
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  echo ">>> 正在添加lz4 1.10.0 & zstd 1.5.7补丁..."
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8750.git
  cp ./oppo_oplus_realme_sm8750/zram_patch/001-lz4.patch ./common/
  cp ./oppo_oplus_realme_sm8750/zram_patch/001-lz4-clearMake.patch ./common/
  cp ./oppo_oplus_realme_sm8750/zram_patch/lz4armv8.S ./common/lib
  cp ./oppo_oplus_realme_sm8750/zram_patch/002-zstd.patch ./common/
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
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/bbrv3_patch/bbrv3_6.6.patch
  patch -p1 -F 3 < bbrv3_6.6.patch || true
  cd ..
  echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
  if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
    echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"
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
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/droidspaces_patch/fix_sysvipc_kabi_6_7_8.patch
  patch -p1 -F 3 < fix_sysvipc_kabi_6_7_8.patch || true
  # 修补 oplus_bsp_midas 行为，避免开机崩溃
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/droidspaces_patch/fix_oplus_bsp_midas.patch
  patch -p1 -F 3 < fix_oplus_bsp_midas.patch || true
  # 应用 NTSync 补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/droidspaces_patch/ntsync_base.patch
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/droidspaces_patch/ntsync_compat_android15-6.6.patch
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
    wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/droidspaces_patch/evdi_drm.patch
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
  echo ">>> 正在启用NoMount挂载模块支持..."
  echo "CONFIG_NOMOUNT=y" >> "$DEFCONFIG_FILE"
  cd ./common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/nomount_patch/nomount.c -O ./fs/nomount.c
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/nomount_patch/nomount.h -O ./fs/nomount.h
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/nomount_patch/nomount_6.6_kernel_integration.patch
  patch -p1 -F 3 < nomount_6.6_kernel_integration.patch || true
  cd ..
fi

# ===== 启用zstdp压缩算法 (移植自 hubai7285-code/ABK) =====
if [[ "$APPLY_ZSTDP" == "y" || "$APPLY_ZSTDP" == "Y" ]]; then
  echo ">>> 正在启用zstdp压缩算法(移植自 hubai7285-code/ABK)..."
  echo ">>> zstdp = zstd preSplit 变种, vendor torvalds/linux v6.15 zstd 源码 + abk_zstdp_ 符号前缀"
  cd "$WORKDIR/kernel_workspace"
  # 拉取 zstdp 集成脚本与源码
  mkdir -p zram_patch/zstdp
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/zram_patch/setup_zstdp.sh -O zram_patch/setup_zstdp.sh
  chmod +x zram_patch/setup_zstdp.sh
  for f in Kconfig Makefile zstdp_namespace.h zstdp_wrapper.c backend_zstdp.c backend_zstdp.h vendor_include_linux_unaligned.h; do
    wget "https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/zram_patch/zstdp/$f" -O "zram_patch/zstdp/$f"
  done
  # 执行集成脚本, 传入内核源码根目录
  ABK_ZSTDP_UPSTREAM_TAG="v6.15" bash zram_patch/setup_zstdp.sh integrate "$PWD/common"
  # 追加 CONFIG 选项
  echo "CONFIG_XXHASH=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_CRYPTO_ZSTDP=y" >> "$DEFCONFIG_FILE"
  # 确保基础 zram 支持
  grep -q "CONFIG_ZRAM=y" "$DEFCONFIG_FILE" || echo "CONFIG_ZRAM=y" >> "$DEFCONFIG_FILE"
  grep -q "CONFIG_ZSMALLOC=y" "$DEFCONFIG_FILE" || echo "CONFIG_ZSMALLOC=y" >> "$DEFCONFIG_FILE"
  # 修复 kallsyms relative 模式 out of range 错误:
  # vendor zstd 源码引入大量符号,ARM64 KASLR 基址(0xffffffc080000000)下
  # 相对偏移可能超出 ±2GB 范围,关闭 BASE_RELATIVE 改用绝对模式
  sed -i '/^CONFIG_KALLSYMS_BASE_RELATIVE=/d' "$DEFCONFIG_FILE"
  echo "# zstdp vendor 引入大量符号, 关闭相对基址以避免 kallsyms out of range" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KALLSYMS_BASE_RELATIVE=n" >> "$DEFCONFIG_FILE"
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 启用省电优化 (低风险组合) =====
if [[ "$APPLY_BATOPT" == "y" || "$APPLY_BATOPT" == "Y" ]]; then
  echo ">>> 正在启用省电优化(低风险组合)..."
  echo ">>> 包含: Log Silencing + Wakelock hard-caps + Schedutil rate-limit + 省电CONFIG块"
  cd ./common
  # 拉取省电优化补丁集
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/battery_patch/silence_logging.patch
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/battery_patch/wakelock_reduction.patch
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/battery_patch/schedutil_ratelimit.patch
  # 按顺序应用,失败时容错跳过
  echo ">>> [1/3] Log Silencing..."
  patch -p1 --forward < silence_logging.patch || echo "warning: silence_logging.patch 应用失败,跳过"
  echo ">>> [2/3] Wakelock hard-caps..."
  patch -p1 --forward < wakelock_reduction.patch || echo "warning: wakelock_reduction.patch 应用失败,跳过"
  echo ">>> [3/3] Schedutil rate-limit..."
  patch -p1 --forward < schedutil_ratelimit.patch || echo "warning: schedutil_ratelimit.patch 应用失败,跳过"
  # 追加省电相关 CONFIG 选项
  echo "# Battery Optimizations (low-risk)" >> "$DEFCONFIG_FILE"
  # 调度器与CPUFreq
  echo "CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_ENERGY_MODEL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SCHED_SMT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SCHED_MC=y" >> "$DEFCONFIG_FILE"
  # UCLAMP: 允许用户态约束后台任务跑小核
  echo "CONFIG_UCLAMP_TASK=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_UCLAMP_TASK_GROUP=y" >> "$DEFCONFIG_FILE"
  # 时钟频率: 100Hz 减少定时器唤醒(轻微降低吞吐,待机场景收益明显)
  sed -i '/^CONFIG_HZ_100=/d; /^CONFIG_HZ_250=/d; /^CONFIG_HZ_300=/d; /^CONFIG_HZ=/d' "$DEFCONFIG_FILE"
  echo "CONFIG_HZ_100=y" >> "$DEFCONFIG_FILE"
  # CPUidle
  echo "CONFIG_CPU_IDLE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_CPU_IDLE_MULTIPLE_DRIVERS=y" >> "$DEFCONFIG_FILE"
  # 动态启用 MGLRU(6.6 内核已合入,mm/lru_gen.c 存在)
  if grep -q "CONFIG_LRU_GEN" "$DEFCONFIG_FILE" || [ -f "mm/lru_gen.c" ]; then
    echo ">>> 检测到 MGLRU 支持,启用 CONFIG_LRU_GEN..."
    echo "CONFIG_LRU_GEN=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_LRU_GEN_ENABLED=y" >> "$DEFCONFIG_FILE"
  fi
  cd ..
fi

# ===== 启用上游安全补丁 =====
if [[ "$APPLY_UPSTREAM" == "y" || "$APPLY_UPSTREAM" == "Y" ]]; then
  echo ">>> 正在启用上游安全补丁(ACK android15-6.6-lts backport + linux-stable 6.6.140/6.6.144)..."
  cd ./common
  # ============================================================
  # 第一部分: rtmutex GhostLock CVE 修复 (linux-stable 6.6.140/6.6.144)
  # ============================================================
  # rtmutex GhostLock CVE-2026-43499: 修复优先级继承链 remove_waiter() 中的悬空指针 UAF
  # 漏洞源于 2.6.39 的 rtmutex 重构,影响所有启用 CONFIG_FUTEX_PI 的内核
  # Google kernelCTF 为此支付 $92,337 奖金,本地提权 + 容器逃逸
  echo ">>> [1/13] rtmutex GhostLock CVE-2026-43499..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/rtmutex_ghostlock_cve-2026-43499.patch
  patch -p1 --forward < rtmutex_ghostlock_cve-2026-43499.patch || echo "warning: CVE-2026-43499 patch 应用失败,可能已合入"
  # rtmutex CVE-2026-53163: 上述修复的后续, syzbot 报告的 NULL-ptr-deref
  # 必须在 CVE-2026-43499 之后应用,依赖其引入的 waiter_task 变量
  echo ">>> [2/13] rtmutex CVE-2026-53163 (后续修复)..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/rtmutex_cve-2026-53163.patch
  patch -p1 --forward < rtmutex_cve-2026-53163.patch || echo "warning: CVE-2026-53163 patch 应用失败,可能已合入"
  # ============================================================
  # 第二部分: ACK android15-6.6-lts backport 补丁集 (6.6.89 -> 6.6.114 缺失补丁)
  # 来源: aosp-mirror/kernel_common android15-6.6-lts 分支
  # 全部为纯上游 UPSTREAM/BACKPORT, 不含 vendor hook / ABI 变更
  # ============================================================
  # dma-buf sysfs export 路径异步化: 把 per-buffer sysfs 文件创建移到 workqueue
  # 避免 export 热路径被 kernfs rw sem 阻塞, 降低 CPU 消耗提升能效
  echo ">>> [3/13] dma-buf sysfs export 路径异步化..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/dma_buf_sysfs_export_path.patch
  patch -p1 --forward < dma_buf_sysfs_export_path.patch || echo "warning: dma-buf sysfs patch 应用失败,可能已合入或上下文不匹配"
  # UFS: 部分 Kioxia UFS 4 设备不支持 qTimestamp 属性, 添加 quirk 跳过避免错误日志
  echo ">>> [4/13] UFS no timestamp quirk..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/ufs_no_timestamp_quirk.patch
  patch -p1 --forward < ufs_no_timestamp_quirk.patch || echo "warning: UFS timestamp quirk patch 应用失败,可能已合入或上下文不匹配"
  # mm/oom_kill: OOM reaper 反向遍历 VMA maple tree, 减少 page table lock 竞争
  echo ">>> [5/13] mm/oom_kill OOM reaper 反向遍历..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/mm_oom_reap_reverse.patch
  patch -p1 --forward < mm_oom_reap_reverse.patch || echo "warning: mm/oom_kill reap reverse patch 应用失败,可能已合入或上下文不匹配"
  # mm/oom_kill: 引入 thaw_process() 解冻整个 OOM victim 进程(而非单线程)
  echo ">>> [6/13] mm/oom_kill thaw 整个 OOM victim..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/mm_oom_thaw_process.patch
  patch -p1 --forward < mm_oom_thaw_process.patch || echo "warning: mm/oom_kill thaw process patch 应用失败,可能已合入或上下文不匹配"
  # mm/list_lru: cgroup.memory=nokmem 时禁用 memcg_aware, 减少不必要的 memcg 操作
  echo ">>> [7/13] mm/list_lru nokmem 禁用 memcg_aware..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/mm_list_lru_nokmem.patch
  patch -p1 --forward < mm_list_lru_nokmem.patch || echo "warning: mm/list_lru nokmem patch 应用失败,可能已合入或上下文不匹配"
  # bpf: 修复 helper 写入只读 map(.rodata)的安全漏洞
  echo ">>> [8/13] bpf 修复 helper 写入只读 map..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/bpf_ro_map_write_fix.patch
  patch -p1 --forward < bpf_ro_map_write_fix.patch || echo "warning: bpf ro map write fix patch 应用失败,可能已合入或上下文不匹配"
  # tls: record header 解析失败时 abort strp, 防止 skb 空间溢出
  echo ">>> [9/13] tls strp abort 防溢出..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/tls_strp_abort.patch
  patch -p1 --forward < tls_strp_abort.patch || echo "warning: tls strp abort patch 应用失败,可能已合入或上下文不匹配"
  # net: ip_output 加 RCU 锁保护 skb->dev 访问, 修复设备注销时 panic
  echo ">>> [10/13] net ip_output dev RCU 保护..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/net_ip_output_dev_rcu.patch
  patch -p1 --forward < net_ip_output_dev_rcu.patch || echo "warning: net ip_output dev rcu patch 应用失败,可能已合入或上下文不匹配"
  # crypto: af_alg_sendmsg 禁止并发写, 修复 socket 内部状态不一致
  echo ">>> [11/13] crypto af_alg 禁止并发写..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/crypto_af_alg_concurrent_write.patch
  patch -p1 --forward < crypto_af_alg_concurrent_write.patch || echo "warning: crypto af_alg concurrent write patch 应用失败,可能已合入或上下文不匹配"
  # arm64: uprobe 模拟 nop 指令, 避免返回用户态执行, 提升 uprobe/uretprobe 性能
  echo ">>> [12/13] arm64 uprobe nop 模拟..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/arm64_uprobe_nop_simulate.patch
  patch -p1 --forward < arm64_uprobe_nop_simulate.patch || echo "warning: arm64 uprobe nop simulate patch 应用失败,可能已合入或上下文不匹配"
  # cpuidle: 回退 "menu: Avoid discarding useful information", 修复性能回归
  echo ">>> [13/13] cpuidle menu revert..."
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/upstream_patch/cpuidle_menu_revert.patch
  patch -p1 --forward < cpuidle_menu_revert.patch || echo "warning: cpuidle menu revert patch 应用失败,可能已合入或上下文不匹配"
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
if [[ "$APPLY_ZSTDP" == "y" || "$APPLY_ZSTDP" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-zstdp"
fi
if [[ "$APPLY_BATOPT" == "y" || "$APPLY_BATOPT" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-batopt"
fi
if [[ "$APPLY_UPSTREAM" == "y" || "$APPLY_UPSTREAM" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-usec"
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
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/nomount_patch/nm.c -O ./nm.c
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/nomount_patch/nm.h -O ./nm.h
  clang --target=aarch64-linux-gnu -static -nostdlib -O2 -ffreestanding -fno-stack-protector -fuse-ld=lld -o ./nm ./nm.c
  file ./nm
  ls -la ./nm

  echo ">>> 复制官方 NoMount 模块模板（含 WebUI）..."
  # 本地仓库就在 $WORKDIR，直接 cp 整个 module 目录
  cp -r "$WORKDIR/nomount_patch/module" ./nomount_module
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
