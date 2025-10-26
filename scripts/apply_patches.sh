#!/usr/bin/bash

apply_zram_patches() {
    local kernel_version="${GKI_ABI:10}"

    cp -r ../SukiSU_patch/other/zram/lz4k/include/linux/* ./common/include/linux
    cp -r ../SukiSU_patch/other/zram/lz4k/lib/* ./common/lib
    cp -r ../SukiSU_patch/other/zram/lz4k/crypto/* ./common/crypto
    cp -r ../SukiSU_patch/other/zram/lz4k_oplus ./common/lib
    cp ../SukiSU_patch/other/zram/zram_patch/$kernel_version/lz4kd.patch ./common

    pushd ./common

    echo 'Patching ZRAM'
    patch -p1 -F 3 < lz4kd.patch || true

    popd
}

apply_manual_hooks_patches() {
    if [[ $SUKISU_MANUAL_HOOKS == true ]]; then
        echo 'Patching manual hooks'
        cp ../../SukiSU_patch/hooks/scope_min_manual_hooks_v1.5.patch ./
        patch -p1 -F 3 < scope_min_manual_hooks_v1.5.patch
    fi
}

add_lz4kd_configs() {
    local android_version="${GKI_ABI:0:9}"
    local kernel_version="${GKI_ABI:10}"
    local config_file=$1

    if [[ $kernel_version == '5.10' ]]; then
        echo 'CONFIG_ZSMALLOC=y' >> $config_file
        echo 'CONFIG_ZRAM=y' >> $config_file
        echo 'CONFIG_MODULE_SIG=n' >> $config_file
        echo 'CONFIG_CRYPTO_LZO=y' >> $config_file
        echo 'CONFIG_ZRAM_DEF_COMP_LZ4KD=y' >> $config_file
    fi

    if [[ $kernel_version != "6.6" ]] && [[ $kernel_version != "5.10" ]]; then
        if grep -q 'CONFIG_ZSMALLOC' -- $config_file; then
            sed -i 's/CONFIG_ZSMALLOC=m/CONFIG_ZSMALLOC=y/g' $config_file
        else
            echo 'CONFIG_ZSMALLOC=y' >> $config_file
        fi

        sed -i 's/CONFIG_ZRAM=m/CONFIG_ZRAM=y/g' $config_file
    fi

    if [[ $kernel_version == '6.6' ]]; then
        echo "CONFIG_ZSMALLOC=y" >> $config_file
        sed -i 's/CONFIG_ZRAM=m/CONFIG_ZRAM=y/g' $config_file
    fi

    if [[ $android_version = 'android14' ]] || [[ $android_version = 'android15' ]]; then
        if [[ -e './modules.bzl' ]]; then
            sed -i 's/"drivers\/block\/zram\/zram\.ko",//g; s/"mm\/zsmalloc\.ko",//g' './modules.bzl'
        fi

        if [[ -e '../msm-kernel/modules.bzl' ]]; then
            sed -i 's/"drivers\/block\/zram\/zram\.ko",//g; s/"mm\/zsmalloc\.ko",//g' '../msm-kernel/modules.bzl'
            echo 'CONFIG_ZSMALLOC=y' >> "../msm-kernel/arch/arm64/configs/$CPU_CODENAME-GKI.config"
            echo 'CONFIG_ZRAM=y' >> "../msm-kernel/arch/arm64/configs/$CPU_CODENAME-GKI.config"
        fi

        echo 'CONFIG_MODULE_SIG_FORCE=n' >> $config_file
    elif [[ $kernel_version = '5.10' ]] || [[ $kernel_version = '5.15' ]]; then
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
}

add_sukisu_configs() {
    pushd ./kernel_platform/common

    local config_file='./arch/arm64/configs/gki_defconfig'

    echo 'CONFIG_KSU=y' >> $config_file
    echo 'CONFIG_KSU_MANUAL_SU=y' >> $config_file

    if [[ $SUKISU_KPM == true ]]; then
        echo 'CONFIG_KPM=y' >> $config_file
    fi

    if [[ $SUKISU_MANUAL_HOOKS == true ]]; then
        echo 'CONFIG_KSU_MANUAL_HOOK=y' >> $config_file 
    else
        echo 'CONFIG_KSU_MANUAL_HOOK=n' >> $config_file
        echo 'CONFIG_KPROBES=y' >> $config_file
    fi

    if [[ $SUSFS_ENABLED == true ]]; then
        echo 'CONFIG_KSU_SUSFS=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_SUS_PATH=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_SUS_MOUNT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_SUS_KSTAT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n' >> $config_file
        echo 'CONFIG_KSU_SUSFS_TRY_UMOUNT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_SPOOF_UNAME=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_ENABLE_LOG=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_OPEN_REDIRECT=y' >> $config_file
        echo 'CONFIG_KSU_SUSFS_SUS_MAP=y' >> $config_file

        if [[ $SUKISU_MANUAL_HOOKS == true ]]; then
            echo 'CONFIG_KSU_SUSFS_SUS_SU=n' >> $config_file
        else
            echo 'CONFIG_KSU_SUSFS_SUS_SU=y' >> $config_file
        fi
    fi

    sed -i 's/check_defconfig//' ./build.config.gki

    if [[ $ZRAM_ENABLED == true ]]; then
        add_lz4kd_configs $config_file
    fi

    popd
}

add_sched() {
    cp -r ./sched_ext/* ./kernel_platform/common/kernel/sched
}

configure_kernel_name() {
    pushd ./kernel_platform
    sed -i "\$s|echo \"\\\$res\"|echo \"\\${KERNEL_NAME}\"|" ./common/scripts/setlocalversion
    sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" ./build/kernel/kleaf/impl/stamp.bzl || true
    # sed -i 's|build-timestamp = $(or $(KBUILD_BUILD_TIMESTAMP), $(build-timestamp-auto))|build-timestamp = "Wed Mar 12 08:35:37 UTC 2025"|' ./common/init/Makefile
    popd
}

apply_susfs_patches() {
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

    apply_manual_hooks_patches

    popd

    if [[ $ZRAM_ENABLED == true ]]; then
        apply_zram_patches
    fi

    popd
}

main() {
    SUSFS_ENABLED=true
    SUKISU_KPM=true
    source repo.conf

    if [[ ! -d workspace ]]; then
        echo 'No workspace found. Please run download_src.sh to download source code first.'
        exit 1
    fi

    set -e
    pushd workspace

    if [[ $SUKISU == true ]]; then
        if [[ $SUSFS_ENABLED == true ]]; then
            apply_susfs_patches
        fi

        add_sukisu_configs
    fi

    if [[ $SCHED_ENABLED == true ]]; then
        add_sched
    fi

    configure_kernel_name

    popd
    set +e
}

main
