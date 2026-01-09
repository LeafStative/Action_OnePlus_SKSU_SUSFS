#!/usr/bin/bash

script_dir=$(dirname $(realpath $0))
source $script_dir/setup.sh

cd workspace/android_kernel_oneplus_sdm845

make \
    O=../out \
    CC=clang \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    READELF=llvm-readelf \
    OBJSIZE=llvm-size \
    STRIP=llvm-strip \
    HOSTCC=clang \
    HOSTCXX=clang++ \
    LLVM_AR=llvm-ar \
    LLVM_DIS=llvm-dis \
    -j$(nproc --all)
