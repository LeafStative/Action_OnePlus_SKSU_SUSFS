#!/usr/bin/bash

repo=$(realpath tools/repo)

init_repo() {
    set -e
    $repo init -u "$REPO_URL" -b "$REPO_BRANCH" -m "$MANIFEST_FILE" --depth=1
    $repo --trace sync -c -j$(nproc) --no-tags --fail-fast

    [[ -e 'kernel_platform/common/BUILD.bazel' ]] &&
        sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' \
        kernel_platform/common/BUILD.bazel

    [[ -e 'kernel_platform/msm-kernel/BUILD.bazel' ]] &&
        sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' \
        kernel_platform/msm-kernel/BUILD.bazel

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
    local init_args=$( [[ $SUKISU_HOOK == 'susfs' ]] && echo '-s susfs-main' || echo '-' )

    set -e
    pushd ./kernel_platform

    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $init_args

    pushd ./KernelSU

    if [[ $SUKISU_VER ]]; then
        sed -i 's/DKSU_VERSION_FULL=\\"\$(KSU_VERSION_FULL)\\"/DKSU_VERSION_FULL=\\"'"$SUKISU_VER"'\\"/' kernel/Makefile
        echo "Custom SukiSU-Ultra version: $SUKISU_VER"
    fi

    popd
    popd
    set +e
}

init_susfs() {
    set -e

    local gki_abi=$(extract_gki_abi kernel_platform/common)
    echo "Detected GKI ABI: $gki_abi"

    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "gki-$gki_abi"
    git clone https://github.com/SukiSU-Ultra/SukiSU_patch
    set +e
}

init_baseband_guard() {
    set -e
    pushd ./kernel_platform/common

    curl -LSs 'https://raw.githubusercontent.com/vc-teahouse/Baseband-guard/main/setup.sh' | bash

    popd
    set +e
}

main() {
    local script_dir=$(dirname $(realpath "$0"))
    source "$script_dir/lib/utils.sh"

    REPO_URL='https://github.com/OnePlusOSS/kernel_manifest'
    SUKISU_HOOK=susfs
    source repo.conf

    mkdir -p workspace
    pushd workspace

    init_repo

    [[ $SCHED_ENABLED == true ]] && init_sched
    [[ $BASEBAND_GUARD_ENABLED == true ]] && init_baseband_guard

    if [[ $SUKISU == true ]]; then
        init_sukisu

        [[ $SUKISU_HOOK == 'susfs' ]] && init_susfs
    fi

    popd
}

main
