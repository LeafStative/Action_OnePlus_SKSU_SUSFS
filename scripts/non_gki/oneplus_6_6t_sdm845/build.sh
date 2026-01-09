#!/usr/bin/bash

main() {
    local script_dir=$(realpath "$0/../../..")
    source "$script_dir/lib/utils.sh"

    source repo.conf

    which python > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        python() {
            python3 $@
        }
        export -f python
    fi

    local tools_path=$(realpath workspace/toolchain)

    PATH="$tools_path/linaro-gcc-4.9/aarch64-linux-gnu/bin:$PATH"
    PATH="$tools_path/linaro-gcc-4.9/arm-linux-gnueabi/bin:$PATH"
    export PATH="$tools_path/clang/host/linux-x86/clang-r428724/bin:$PATH"
    export ARCH=arm64
    export SUBARCH=ARM64
    export CLANG_TRIPLE=aarch64-linux-gnu-
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

    if [[ ! -d workspace/android_kernel ]]; then
        echo 'No kernel source found. Please run download_src.sh to download source code first.'
        exit 1
    fi

    pushd workspace
    pushd android_kernel
    make \
        O=../out \
        clean \
        mrproper \
        LLVM=1 \
        LLVM_AR=llvm-ar \
        LLVM_DIS=llvm-dis \
        enchilada_defconfig

    make \
        O=../out \
        LLVM=1 \
        LLVM_AR=llvm-ar \
        LLVM_DIS=llvm-dis \
        -j$(nproc --all)

    local image_path=$(realpath -m '../out/arch/arm64/boot/Image')
    if [[ ! -f $image_path ]]; then
        echo 'Build failed!'
        exit 1
    fi

    local kernel_version=$(strings $image_path | grep -oP '(?<=Linux version )\d\S+')
    echo "Kernel version: $kernel_version"

    popd

    [[ $SUKISU_KPM == 'full' ]] && patch_kpm ./SukiSU_patch/kpm/patch_linux "$(dirname "$image_path")"

    popd

    echo Build successful
}

main $1
