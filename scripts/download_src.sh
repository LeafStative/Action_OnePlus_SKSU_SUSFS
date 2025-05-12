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

init_kernelsu() {
    local init_args
    if [[ $KSU_BRANCH == 'tag' ]]; then
        init_args=-
    elif [[ $KSU_BRANCH == 'main' ]]; then
        if [[ $KSU == 'ksun' ]]; then
            init_args='-s next'
        else
            init_args='-s main'
        fi

        if [[ $SUSFS_ENABLED == true ]]; then
            case "$KSU" in
                rksu)
                    init_args='-s susfs-v1.5.7'
                    ;;
                sksu)
                    init_args='-s susfs-stable'
                    ;;
            esac
        fi
    fi

    set -e
    pushd ./kernel_platform
    case "$KSU" in
        official)
            curl -LSs 'https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh' | bash $init_args
            ;;
        ksun)
            curl -LSs 'https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh' | bash $init_args
            ;;
        mksu)
            curl -LSs 'https://raw.githubusercontent.com/5ec1cff/KernelSU/main/kernel/setup.sh' | bash $init_args
            ;;
        rksu)
            curl -LSs 'https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh' | bash $init_args
            ;;
        sksu)
            curl -LSs 'https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh' | bash $init_args
            ;;
    esac
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
    KSU_BRANCH=main
    SUSFS_ENABLED=true
    source repo.conf

    mkdir -p workspace
    pushd workspace

    init_repo

    if [[ $KSU ]]; then
        init_kernelsu

        if [[ $SUSFS_ENABLED == true ]]; then
            init_susfs
        fi
    fi

    popd
}

main
