#!/usr/bin/bash

apply_sukisu_susfs_patches() {
    # TODO
}

apply_manual_hooks_patches() {
    if [[ $SUSFS_ENABLED == true && $SUKISU_MANUAL_HOOKS == true ]]; then
        echo 'Patching manual hooks'
        cp ../../SukiSU_patch/hooks/syscall_hooks.patch ./
        patch -p1 -F 3 < syscall_hooks.patch.patch
    fi
}

add_sukisu_configs() {
    pushd ./kernel_platform/common

    local config_file='./arch/arm64/configs/gki_defconfig'

    echo "CONFIG_KSU=y" >> $config_file

    if [[ $SUKISU_KPM == true ]]; then
        echo 'CONFIG_KPM=y' >> $config_file
    fi

    if [[ $SUKISU_MANUAL_HOOKS == true && $SUSFS_ENABLED == true ]]; then
        echo 'CONFIG_KSU_MANUAL_HOOK=y' >> $config_file 
    else
        echo 'CONFIG_KSU_MANUAL_HOOK=n' >> $config_file
    fi

    if [[ $SUKISU_MANUAL_HOOKS != true ]]; then
        echo 'CONFIG_KPROBES=y' >> $config_file
    fi

    if [[ $SUSFS_ENABLED == true ]]; then
        echo "CONFIG_KSU_SUSFS=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n" >> $config_file
        echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $config_file
        echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> $config_file

        if [[ $SUKISU_MANUAL_HOOKS == true ]]; then
            echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $config_file
        else
            echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> $config_file
        fi
    fi

    sed -i 's/check_defconfig//' ./build.config.gki

    # TODO: LZ4KD
    popd
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
    cp ../susfs4ksu/kernel_patches/50_add_susfs_in_$SUSFS_BRANCH.patch ./common
    cp ../susfs4ksu/kernel_patches/fs/* ./common/fs
    cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux

    # TODO: ZRAM

    apply_sukisu_susfs_patches

    cp ../SukiSU_patch/69_hide_stuff.patch ./common

    pushd ./common
    echo 'Patching SUSFS'
    patch -p1 < 50_add_susfs_in_$SUSFS_BRANCH.patch || true
    
    echo 'Patching 69_hide_stuff.patch'
    patch -p1 -F 3 < 69_hide_stuff.patch

    apply_manual_hooks_patches
    popd

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

    configure_kernel_name

    popd
    set +e
}

main
