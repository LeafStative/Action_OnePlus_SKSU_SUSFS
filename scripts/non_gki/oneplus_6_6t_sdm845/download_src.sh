#!/usr/bin/bash

repo=$(realpath tools/repo)

init_repo() {
    set -e

    local branch_flags=''
    if [ $REPO_BRANCH ]; then
        local branch_flags="-b '$REPO_BRANCH'"
    fi

    echo 'Downloading toolchain...'
    git clone https://github.com/Akitlove/android-kernel-tools toolchain --depth=1 -b clang13

    echo 'Downloading kernel source code...'
    git clone "$REPO_URL" --depth=1 $branch_flags android_kernel

    sed -i 's/ -dirty//g' android_kernel/scripts/setlocalversion
    set +e
}

init_sukisu() {
    local init_args=$( [[ $SUSFS_ENABLED == true ]] && echo '-s susfs-main' || echo '-s nongki' )

    set -e
    pushd android_kernel

    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $init_args

    if [[ $SUKISU_VER ]]; then
        sed -i 's/DKSU_VERSION_FULL=\\"\$(KSU_VERSION_FULL)\\"/DKSU_VERSION_FULL=\\"'"$SUKISU_VER"'\\"/' kernel/Makefile
        echo "Custom SukiSU-Ultra version: $SUKISU_VER"
    fi

    popd
    set +e
}

init_susfs() {
    set -e
    git clone https://github.com/SukiSU-Ultra/SukiSU_patch
    set +e
}

main() {
    KERNEL_REPO='LineageOS/android_kernel_oneplus_sdm845'
    SUSFS_ENABLED=true
    source repo.conf

    REPO_URL="https://github.com/$KERNEL_REPO"

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
