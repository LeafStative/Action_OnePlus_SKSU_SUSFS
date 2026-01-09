#!/usr/bin/bash

script_dir=$(dirname $(realpath $0))
source $script_dir/setup.sh

cd workspace/android_kernel_oneplus_sdm845

make \
    O=../out \
    clean \
    mrproper
