#!/usr/bin/bash

patch_kpm() {
    echo 'KernelPatch module enabled, patching kernel image'

    local image_dir=$(dirname $1)
    cp ../SukiSU_patch/kpm/patch_linux "$image_dir"
    pushd $image_dir

    chmod a+x ./patch_linux
    ./patch_linux

    mv Image Image.bak
    mv oImage Image

    echo 'Kernel image patched'

    popd
}

main() {
    SUKISU_KPM=true
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

    pushd workspace/android_kernel
    make \
        O=out \
        clean \
        mrproper \
        LLVM=1 \
        LLVM_AR=llvm-ar \
        LLVM_DIS=llvm-dis \
        enchilada_defconfig
    
    make \
        O=out \
        LLVM=1 \
        LLVM_AR=llvm-ar \
        LLVM_DIS=llvm-dis \
        -j$(nproc --all)

    local image_path='out/arch/arm64/boot/Image'
    if [[ ! -f $image_path ]]; then
        echo 'Build failed!'
        exit 1
    fi

    local kernel_version=$(strings $image_path | grep -oP '(?<=Linux version )\d\S+')

    echo "Kernel version: $kernel_version"

    [[ $SUKISU_KPM == true ]] && patch_kpm $image_path

    popd

    echo Build successful
}

main $1
