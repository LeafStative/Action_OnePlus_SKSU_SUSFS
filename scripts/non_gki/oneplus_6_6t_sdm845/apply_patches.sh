#!/usr/bin/bash

apply_manual_hooks_patches() {
    echo 'Patching manual hooks'
    cp "$PATCHES_DIR/manual-hooks.patch" ./
    patch -p1 < manual-hooks.patch
}

add_sukisu_configs() {
    local config_file='./arch/arm64/configs/enchilada_defconfig'

    echo 'CONFIG_KSU=y' >> $config_file
    echo 'CONFIG_KSU_MANUAL_SU=y' >> $config_file

    [[ $SUKISU_DEBUG == true ]] && echo 'CONFIG_KSU_DEBUG=y' >> $config_file
    [[ $SUKISU_KPM == 'full' || $SUKISU_KPM == 'compile-only' ]] && echo 'CONFIG_KPM=y' >> $config_file

    if [[ $SUSFS_ENABLED == true ]]; then
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
    else
        echo 'CONFIG_KSU_MANUAL_HOOK=y' >> $config_file
    fi
}

configure_kernel_name() {
    local hash=$(git rev-parse --verify HEAD | cut -c1-12)
    local kernel_name="-g$hash$KERNEL_SUFFIX"
    sed -i "\$s|echo \"\\\$res\"|echo \"\\${kernel_name}\"|" ./scripts/setlocalversion
    # sed -i 's|build-timestamp = $(or $(KBUILD_BUILD_TIMESTAMP), $(build-timestamp-auto))|build-timestamp = "Wed Mar 12 08:35:37 UTC 2025"|' ./common/init/Makefile
}

apply_susfs_patches() {
    cp "$PATCHES_DIR/susfs.patch" ./
    cp ../SukiSU_patch/69_hide_stuff.patch ./

    echo 'Patching SUSFS'
    patch -p1 < susfs.patch

    echo 'Patching 69_hide_stuff.patch'
    patch -p1 -F 3 < 69_hide_stuff.patch
}

apply_sukisu_patches() {
    if [[ $SUKISU_KPM == 'full' || $SUKISU_KPM == 'compile-only' ]]; then
        echo 'Patching for KPM support'
        cp "$PATCHES_DIR/set_memory.h" ./include/linux
    fi

    cp "$PATCHES_DIR/modules-fix.patch" ./
    cp "$PATCHES_DIR/path_umount.patch" ./

    patch -p1 < modules-fix.patch
    patch -p1 < path_umount.patch
}

add_baseband_guard_configs() {
    local config_file='./arch/arm64/configs/enchilada_defconfig'
    echo 'CONFIG_BBG=y' >> $config_file
}

main() {
    SUSFS_ENABLED=true
    source repo.conf

    PATCHES_DIR=$(realpath patches/oneplus_6_6t_sdm845)

    if [[ ! -d workspace ]]; then
        echo 'No workspace found. Please run download_src.sh to download source code first.'
        exit 1
    fi

    set -e
    pushd workspace/android_kernel

    if [[ $SUKISU == true ]]; then
        apply_sukisu_patches

        [[ $SUSFS_ENABLED == true ]] && apply_susfs_patches || apply_manual_hooks_patches

        add_sukisu_configs
    fi

    [[ $BASEBAND_GUARD_ENABLED == true ]] && add_baseband_guard_configs

    configure_kernel_name

    popd
    set +e
}

main
