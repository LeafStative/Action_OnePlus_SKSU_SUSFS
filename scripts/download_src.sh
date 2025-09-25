#!/usr/bin/bash

repo=`realpath tools/repo`

init_repo() {
    set -e
    $repo init -u "$REPO_URL" -b "$REPO_BRANCH" -m "$MANIFEST_FILE" --depth=1
    $repo --trace sync -c -j$(nproc) --no-tags --fail-fast

    if [ -e 'kernel_platform/common/BUILD.bazel' ]; then
        sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' \
        kernel_platform/common/BUILD.bazel
    fi

    if [[ -e 'kernel_platform/msm-kernel/BUILD.bazel' ]]; then
        sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' \
        kernel_platform/msm-kernel/BUILD.bazel
    fi

    rm kernel_platform/common/android/abi_gki_protected_exports_* || echo "No protected exports!"
    rm kernel_platform/msm-kernel/android/abi_gki_protected_exports_* || echo "No protected exports!"

    sed -i 's/ -dirty//g' kernel_platform/common/scripts/setlocalversion
    sed -i 's/ -dirty//g' kernel_platform/msm-kernel/scripts/setlocalversion
    sed -i 's/ -dirty//g' kernel_platform/external/dtc/scripts/setlocalversion
    set +e
}

init_sched() {
    set -e
    git clone https://github.com/HanKuCha/sched_ext --depth=1
    rm -rf ./sched_ext/.git
    set +e
}

init_sukisu() {
    local init_args=$( [[ $SUSFS_ENABLED == true ]] && echo '-s susfs-main' || echo '-' )

    set -e
    pushd ./kernel_platform

    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $init_args

    pushd ./KernelSU

    local sukisu_ver
    if [[ $SUKISU_VER ]]; then
        sukisu_ver=$SUKISU_VER
    else
        sukisu_ver=$(( $(git rev-list --count main) + 10606 ))
    fi

    sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=$sukisu_ver/" kernel/Makefile
    echo "SukiSU-Ultra version: $sukisu_ver"

    popd
    popd
    set +e
}

init_susfs() {
    set -e
    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "gki-$GKI_ABI"
    git clone https://github.com/SukiSU-Ultra/SukiSU_patch
    set +e
}

main() {
    REPO_URL='https://github.com/OnePlusOSS/kernel_manifest'
    SUSFS_ENABLED=true
    source repo.conf

    mkdir -p workspace
    pushd workspace

    init_repo

    if [[ $SCHED_ENABLED == true ]]; then
        init_sched
    fi

    if [[ $SUKISU == true ]]; then
        init_sukisu

        if [[ $SUSFS_ENABLED == true ]]; then
            init_susfs
        fi
    fi

    popd
}

main
