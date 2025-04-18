#!/usr/bin/bash

apply_ksu_susfs_patches() {
    case "$KSU" in
        official)
            cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU
            pushd ./KernelSU
            patch -p1 --forward < 10_enable_susfs_for_ksu.patch || true
            popd
            ;;
        ksun)
            cp ../kernel_patches4mksu/next/0001-kernel-patch-susfs-v1.5.5-to-KernelSU-Next-v1.0.5.patch ./KernelSU-Next
            pushd ./KernelSU-Next
            patch -p1 --forward < 0001-kernel-patch-susfs-v1.5.5-to-KernelSU-Next-v1.0.5.patch || true
            ;;
        mksu)
            cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU
            cp ../kernel_patches4mksu/mksu/mksu_susfs.patch ./KernelSU
            cp ../kernel_patches4mksu/mksu/fix.patch ./KernelSU
            pushd ./KernelSU
            patch -p1 --forward < 10_enable_susfs_for_ksu.patch || true
            patch -p1 < mksu_susfs.patch || true
            patch -p1 < fix.patch || true
            popd
            ;;
    esac
}

apply_new_hooks_patches() {
    case "$KSU" in
        ksun)
            cp ../../kernel_patches4mksu/next/syscall_hooks.patch ./
            patch -p1 -F 3 < syscall_hooks.patch
            ;;
        sksu)
            cp ../../kernel_patches4mksu/hooks/new_hooks.patch ./
            patch -p1 -F 3 < new_hooks.patch
            ;;
    esac
}

add_susfs_configs() {
    local config_file='./arch/arm64/configs/gki_defconfig'
    if [[ $KSU == 'sksu' ]]; then
        echo 'CONFIG_KPM=y' >> $config_file
        echo 'CONFIG_KSU_MANUAL_HOOK=y' >> $config_file
    else
        echo 'CONFIG_KSU_WITH_KPROBES=y' >> $config_file
        # echo 'CONFIG_KSU_WITH_KPROBES=n' >> $config_file
    fi

    echo "CONFIG_KSU=y" >> $config_file
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
    echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $config_file
    sed -i 's/check_defconfig//' ./build.config.gki
}

configure_ksu_version() {
    local makefile='kernel/Makefile'

    local default_version
    case "$KSU" in
        ksun)
            pushd ./kernel_platform/KernelSU-Next
            default_version=11998
            ;;
        sksu)
            pushd ./kernel_platform/SukiSU-Ultra
            default_version=12500
            ;;
        *)
            pushd ./kernel_platform/KernelSU
            default_version=16
            ;;
    esac

    local ksu_ver
    if [[ $KSU_VER ]]; then
        ksu_ver=$KSU_VER
    else
        if [[ $KSU == 'sksu' ]]; then
            ksu_ver=$(( $(git rev-list --count main) + 10606 ))
        else
            ksu_ver=$(( $(git rev-list --count HEAD) + 10200 ))
        fi
    fi

    sed -i "s/DKSU_VERSION=$default_version/DKSU_VERSION=$ksu_ver/" "$makefile"

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
    cp ../susfs4ksu/kernel_patches/50_add_susfs_in_$SUSFS_BRANCH.patch ./common/
    cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
    cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

    apply_ksu_susfs_patches

    cp ../kernel_patches4mksu/69_hide_stuff.patch ./common

    pushd ./common
    patch -p1 < 50_add_susfs_in_$SUSFS_BRANCH.patch || true
    patch -p1 -F 3 < 69_hide_stuff.patch

    apply_new_hooks_patches
    add_susfs_configs
    popd

    popd
}

main() {
    SUSFS_ENABLED=true
    source repo.conf

    set -e
    if [[ $KSU ]]; then
        if [[ $SUSFS_ENABLED == true ]]; then
            apply_susfs_patches
        fi

        configure_ksu_version
    fi

    configure_kernel_name
    set +e
}

main
