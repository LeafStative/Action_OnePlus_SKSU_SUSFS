#!/usr/bin/bash

apply_manual_hooks_patches() {
    echo 'Patching manual hooks'
    cp "$PATCHES_DIR/syscall-hooks.patch" ./
    patch -p1 < syscall-hooks.patch
}

add_sukisu_configs() {
    local config_file='./arch/arm64/configs/enchilada_defconfig'

    echo 'CONFIG_KSU=y' >> $config_file

    if [[ $SUKISU_DEBUG == true ]]; then
        echo 'CONFIG_KSU_DEBUG=y' >> $config_file
    fi

    if [[ $SUKISU_KPM == true ]]; then
        echo 'CONFIG_KPM=y' >> $config_file
    fi

    echo 'CONFIG_KSU_MANUAL_HOOK=y' >> $config_file

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
        echo 'CONFIG_KSU_SUSFS_SUS_SU=n' >> $config_file
    fi
}

configure_kernel_name() {
    local hash=`git rev-parse --short HEAD`
    local kernel_name="-g$hash$KERNEL_SUFFIX"
    sed -i "\$s|echo \"\\\$res\"|echo \"\\${KERNEL_SUFFIX}\"|" ./scripts/setlocalversion
    # sed -i 's|build-timestamp = $(or $(KBUILD_BUILD_TIMESTAMP), $(build-timestamp-auto))|build-timestamp = "Wed Mar 12 08:35:37 UTC 2025"|' ./common/init/Makefile
}

apply_susfs_patches() {
    cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-android12-5.10.patch .
    cp ../susfs4ksu/kernel_patches/fs/* ./fs
    cp ../susfs4ksu/kernel_patches/include/linux/* ./include/linux
    cp "$PATCHES_DIR/susfs-fix.patch" .

    cp ../SukiSU_patch/69_hide_stuff.patch .

    echo 'Patching SUSFS'
    git apply --reject 50_add_susfs_in_gki-android12-5.10.patch || true
    patch -p1 < susfs-fix.patch

    echo 'Patching 69_hide_stuff.patch'
    patch -p1 -F 3 < 69_hide_stuff.patch
}

apply_sukisu_patches() {
    if [[ $SUKISU_KPM == true ]]; then
        echo 'Patching for KPM support'
        cp "$PATCHES_DIR/set_memory.h" ./include/linux
    fi

    cp "$PATCHES_DIR/modules-fix.patch" .
    cp "$PATCHES_DIR/path_umount.patch" .

    patch -p1 < modules-fix.patch
    patch -p1 < path_umount.patch
}

main() {
    SUSFS_ENABLED=true
    SUKISU_KPM=true
    source repo.conf

    PATCHES_DIR=`realpath patches/oneplus_6_6t_sdm845`

    if [[ ! -d workspace ]]; then
        echo 'No workspace found. Please run download_src.sh to download source code first.'
        exit 1
    fi

    set -e
    pushd workspace/android_kernel

    if [[ $SUKISU == true ]]; then
        apply_sukisu_patches

        if [[ $SUSFS_ENABLED == true ]]; then
            apply_susfs_patches
        fi

        apply_manual_hooks_patches
        add_sukisu_configs
    fi

    configure_kernel_name

    popd
    set +e
}

main
