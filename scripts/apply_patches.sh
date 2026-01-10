#!/usr/bin/bash

defconfig_add_generic() {
    pushd ./kernel_platform/common

    local config_file='./arch/arm64/configs/gki_defconfig'

    echo 'CONFIG_TMPFS_XATTR=y' >> $config_file
    echo 'CONFIG_TMPFS_POSIX_ACL=y' >> $config_file

    popd
}

patch_ogki() {
    [[ $SCHED_ENABLED == true ]] && return 0

    local version patchlevel
    IFS='.' read version patchlevel <<< "$(extract_kernel_version ./kernel_platform/common 2)"
    [[ $version < 6 && $patchlevel < 6 ]] && return 0

    pushd ./kernel_platform/common

    for path in ./kernel/sched/hmbird* ./vendor/oplus/kernel/cpu/sched_ext/hmbird*; do
        [[ -d $path ]] && return 0
    done

    echo 'Patching OGKI'
    sed -i '1iobj-y += hmbird_patch.o' drivers/Makefile
    patch -p1 -F 3 < "$PATCHES_DIR/ogki_convert.patch" || true

    popd
}

defconfig_add_bbr_ecn() {
    pushd ./kernel_platform/common

    local config_file='./arch/arm64/configs/gki_defconfig'

    echo 'CONFIG_TCP_CONG_ADVANCED=y' >> "$config_file"
    echo 'CONFIG_TCP_CONG_BBR=y' >> "$config_file"
    echo 'CONFIG_NET_SCH_FQ=y' >> "$config_file"
    echo 'CONFIG_TCP_CONG_BIC=n' >> "$config_file"
    echo 'CONFIG_TCP_CONG_WESTWOOD=n' >> "$config_file"
    echo 'CONFIG_TCP_CONG_HTCP=n' >> "$config_file"
    echo 'CONFIG_IP_ECN=y' >> "$config_file"
    echo 'CONFIG_TCP_ECN=y' >> "$config_file"
    echo 'CONFIG_IPV6_ECN=y' >> "$config_file"
    echo 'CONFIG_IP_NF_TARGET_ECN=y' >> "$config_file"

    popd
}

patch_zram() {
    cp -r ./SukiSU_patch/other/zram/lz4k/include/linux/* ./kernel_platform/common/include/linux
    cp -r ./SukiSU_patch/other/zram/lz4k/lib/* ./kernel_platform/common/lib
    cp -r ./SukiSU_patch/other/zram/lz4k/crypto/* ./kernel_platform/common/crypto
    cp -r ./SukiSU_patch/other/zram/lz4k_oplus ./kernel_platform/common/lib

    local kernel_version="${GKI_ABI:10}"
    cp ./SukiSU_patch/other/zram/zram_patch/$kernel_version/*.patch ./kernel_platform/common

    pushd ./kernel_platform/common

    echo 'Patching ZRAM'
    patch -p1 -F 3 < lz4kd.patch || true
    patch -p1 -F 3 < lz4k_oplus.patch || true

    # Modify defconfig
    local config_file='./arch/arm64/configs/gki_defconfig'

    if [[ $kernel_version == '5.10' ]]; then
        echo 'CONFIG_ZSMALLOC=y' >> $config_file
        echo 'CONFIG_ZRAM=y' >> $config_file
        echo 'CONFIG_MODULE_SIG=n' >> $config_file
        echo 'CONFIG_CRYPTO_LZO=y' >> $config_file
        echo 'CONFIG_ZRAM_DEF_COMP_LZ4KD=y' >> $config_file
    fi

    if [[ $kernel_version != "6.12" && $kernel_version != '6.6' && $kernel_version != "5.10" ]]; then
        if grep -q 'CONFIG_ZSMALLOC' -- $config_file; then
            sed -i 's/CONFIG_ZSMALLOC=m/CONFIG_ZSMALLOC=y/g' $config_file
        else
            echo 'CONFIG_ZSMALLOC=y' >> $config_file
        fi

        sed -i 's/CONFIG_ZRAM=m/CONFIG_ZRAM=y/g' $config_file
    fi

    if [[ $kernel_version == '6.12' || $kernel_version == '6.6' ]]; then
        echo "CONFIG_ZSMALLOC=y" >> $config_file
        sed -i 's/CONFIG_ZRAM=m/CONFIG_ZRAM=y/g' $config_file
    fi

    local android_version="${GKI_ABI:0:9}"
    if [[ $android_version == 'android14' || $android_version == 'android15' || $android_version == 'android16' ]]; then
        [[ -e './modules.bzl' ]] && sed -i 's/"drivers\/block\/zram\/zram\.ko",//g; s/"mm\/zsmalloc\.ko",//g' './modules.bzl'

        if [[ -e '../msm-kernel/modules.bzl' ]]; then
            sed -i 's/"drivers\/block\/zram\/zram\.ko",//g; s/"mm\/zsmalloc\.ko",//g' '../msm-kernel/modules.bzl'
            echo 'CONFIG_ZSMALLOC=y' >> "../msm-kernel/arch/arm64/configs/$CPU_CODENAME-GKI.config"
            echo 'CONFIG_ZRAM=y' >> "../msm-kernel/arch/arm64/configs/$CPU_CODENAME-GKI.config"
        fi

        echo 'CONFIG_MODULE_SIG_FORCE=n' >> $config_file
    elif [[ $kernel_version == '5.10' || $kernel_version == '5.15' ]]; then
        rm ./android/gki_aarch64_modules
        touch ./android/gki_aarch64_modules
    fi

    if grep -q 'CONFIG_ZSMALLOC=y' $config_file && grep -q 'CONFIG_ZRAM=y' $config_file; then
        echo 'CONFIG_CRYPTO_LZ4HC=y' >> $config_file
        echo 'CONFIG_CRYPTO_LZ4K=y' >> $config_file
        echo 'CONFIG_CRYPTO_LZ4KD=y' >> $config_file
        echo 'CONFIG_CRYPTO_842=y' >> $config_file
        echo 'CONFIG_ZRAM_WRITEBACK=y' >> $config_file
    fi

    popd
}

patch_manual_hooks() {
    pushd ./kernel_platform/common

    echo 'Patching manual hooks'
    cp ../../SukiSU_patch/hooks/scope_min_manual_hooks_v1.6.patch ./
    patch -p1 -F 3 < scope_min_manual_hooks_v1.6.patch

    popd
}

defconfig_add_sukisu() {
    pushd ./kernel_platform/common

    local config_file='./arch/arm64/configs/gki_defconfig'

    echo 'CONFIG_KSU=y' >> $config_file
    echo 'CONFIG_KSU_MANUAL_SU=y' >> $config_file

    [[ $SUKISU_KPM == 'full' || $SUKISU_KPM == 'compile-only' ]] && echo 'CONFIG_KPM=y' >> $config_file

    case "$SUKISU_HOOK" in
        manual)
            echo 'CONFIG_KSU_MANUAL_HOOK=y' >> $config_file
            ;;
        kprobes)
            echo 'CONFIG_KSU_SYACALL_HOOK=y' >> $config_file
            echo 'CONFIG_KPROBES=y' >> $config_file
            ;;
        susfs)
            echo 'CONFIG_KSU_NONE_HOOK=y' >> $config_file

            echo 'CONFIG_KSU_SUSFS=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_SUS_PATH=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_SUS_MOUNT=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_SUS_KSTAT=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_SPOOF_UNAME=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_ENABLE_LOG=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_OPEN_REDIRECT=y' >> $config_file
            echo 'CONFIG_KSU_SUSFS_SUS_MAP=y' >> $config_file
            ;;
    esac

    sed -i 's/check_defconfig//' ./build.config.gki

    popd
}

patch_sched() {
    local manifest_name=$(basename "$MANIFEST_FILE" .xml)

    if [[ ! -f "./SCHED_PATCH/fengchi_${manifest_name}.patch" ]]; then
        echo "No sched patch found for '$manifest_name'"
        return 1
    fi

    cp "./SCHED_PATCH/fengchi_${manifest_name}.patch" ./kernel_platform/common

    pushd ./kernel_platform/common

    echo 'Patching SCHED'
    dos2unix "fengchi_${manifest_name}.patch"
    patch -p1 -F 3 < "fengchi_${manifest_name}.patch"

    popd
}

configure_kernel_name() {
    pushd ./kernel_platform
    sed -i "\$s|echo \"\\\$res\"|echo \"\\${KERNEL_SUFFIX}\"|" ./common/scripts/setlocalversion
    sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" ./build/kernel/kleaf/impl/stamp.bzl || true
    # sed -i 's|build-timestamp = $(or $(KBUILD_BUILD_TIMESTAMP), $(build-timestamp-auto))|build-timestamp = "Wed Mar 12 08:35:37 UTC 2025"|' ./common/init/Makefile
    popd
}

patch_susfs() {
    pushd ./kernel_platform

    cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-$GKI_ABI.patch ./common
    cp ../susfs4ksu/kernel_patches/fs/* ./common/fs
    cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux

    cp ../SukiSU_patch/69_hide_stuff.patch ./common

    pushd ./common
    echo 'Patching SUSFS'
    patch -p1 < 50_add_susfs_in_gki-$GKI_ABI.patch || true

    echo 'Patching 69_hide_stuff.patch'
    patch -p1 -F 3 < 69_hide_stuff.patch

    popd
    popd
}

patch_baseband_guard() {
    sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' \
        ./kernel_platform/common/security/Kconfig

    local config_file='./kernel_platform/common/arch/arm64/configs/gki_defconfig'
    echo 'CONFIG_BBG=y' >> $config_file
}

patch_netfilter() {
    pushd ./kernel_platform/common

    # MediaTek SoCs does not need this patch.
    patch -p1 -F 3 "${PATCHES_DIR}/ipv6-fix.patch"

    echo 'CONFIG_BPF_STREAM_PARSER=y' >> "$config_file"
    echo 'CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y' >> "$config_file"
    echo 'CONFIG_NETFILTER_XT_SET=y' >> "$config_file"
    echo 'CONFIG_IP_SET=y' >> "$config_file"
    echo 'CONFIG_IP_SET_MAX=6534' >> "$config_file"
    echo 'CONFIG_IP_SET_BITMAP_IP=y' >> "$config_file"
    echo 'CONFIG_IP_SET_BITMAP_IPMAC=y' >> "$config_file"
    echo 'CONFIG_IP_SET_BITMAP_PORT=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_IP=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_IPMARK=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_IPPORT=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_IPPORTIP=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_IPPORTNET=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_IPMAC=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_MAC=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_NETPORTNET=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_NET=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_NETNET=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_NETPORT=y' >> "$config_file"
    echo 'CONFIG_IP_SET_HASH_NETIFACE=y' >> "$config_file"
    echo 'CONFIG_IP_SET_LIST_SET=y' >> "$config_file"
    echo 'CONFIG_IP6_NF_NAT=y' >> "$config_file"
    echo 'CONFIG_IP6_NF_TARGET_MASQUERADE=y' >> "$config_file"

    popd
}

main() {
    local script_dir=$(dirname $(realpath "$0"))
    source "$script_dir/lib/utils.sh"

    SUKISU_HOOK=susfs
    source repo.conf

    PATCHES_DIR=$(realpath ./patches)

    if [[ ! -d workspace ]]; then
        echo 'No workspace found. Please run download_src.sh to download source code first.'
        exit 1
    fi

    set -e
    pushd workspace

    GKI_ABI=$(extract_gki_abi ./kernel_platform/common)

    patch_ogki
    defconfig_add_generic

    [[ $BBR_ECN_ENABLED == true ]] && defconfig_add_bbr_ecn
    [[ $ZRAM_ENABLED == true ]] && patch_zram

    if [[ $SUKISU == true ]]; then
        case $SUKISU_HOOK in
            susfs)
                patch_susfs
                ;;
            manual)
                patch_manual_hooks
                ;;
        esac

        defconfig_add_sukisu
    fi

    [[ $SCHED_ENABLED == true ]] && patch_sched
    [[ $BASEBAND_GUARD_ENABLED == true ]] && patch_baseband_guard
    [[ $NETFILTER_ENABLED == true ]] && patch_netfilter

    configure_kernel_name

    popd
    set +e
}

main
