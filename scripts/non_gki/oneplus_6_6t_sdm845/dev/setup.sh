#!/usr/bin/bash

tools_path=$(realpath workspace/toolchain)

PATH="$tools_path/linaro-gcc-4.9/aarch64-linux-gnu/bin:$PATH"
PATH="$tools_path/linaro-gcc-4.9/arm-linux-gnueabi/bin:$PATH"
export PATH="$tools_path/clang/host/linux-x86/clang-r428724/bin:$PATH"
export ARCH=arm64
export SUBARCH=ARM64
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
