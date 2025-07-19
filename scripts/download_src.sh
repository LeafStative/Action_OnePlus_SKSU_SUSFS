#!/usr/bin/bash

repo=`realpath tools/repo`

init_repo() {
    set -e
    $repo init -u "$REPO_URL" -b "$REPO_BRANCH" -m "$MANIFEST_FILE" --depth=1
    $repo --trace sync -c -j$(nproc) --no-tags --fail-fast

    rm kernel_platform/common/android/abi_gki_protected_exports_* || echo "No protected exports!"
    rm kernel_platform/msm-kernel/android/abi_gki_protected_exports_* || echo "No protected exports!"
    sed -i 's/ -dirty//g' kernel_platform/common/scripts/setlocalversion
    sed -i 's/ -dirty//g' kernel_platform/msm-kernel/scripts/setlocalversion
    set +e
}

init_sukisu() {
    local init_args=$( [[ $SUSFS_ENABLED == true ]] && echo '-s susfs-main' || echo '-' )

    set -e
    pushd ./kernel_platform
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $init_args
    popd
    set +e
}

init_susfs() {
    set -e
    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b $SUSFS_BRANCH
    git clone https://github.com/TanakaLun/kernel_patches4mksu.git
    set +e
}

main() {
    REPO_URL='https://github.com/OnePlusOSS/kernel_manifest'
    SUSFS_ENABLED=true
    source repo.conf

    mkdir -p workspace
    pushd workspace

    init_repo

    if [[ $SUKISU == true ]]; then
        init_sukisu

        if [[ $SUSFS_ENABLED == true ]]; then
            init_susfs
        fi
    fi

    popd
}

main
