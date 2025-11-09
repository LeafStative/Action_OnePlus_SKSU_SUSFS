#!/usr/bin/bash

patch_kpm() {
    echo 'KernelPatch module enabled, patching kernel image'

    cp ./SukiSU_patch/kpm/patch_linux ./out/dist
    pushd out/dist

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

    if [[ ! -d workspace ]]; then
        echo 'No workspace found. Please run download_src.sh to download source code first.'
        exit 1
    fi
    pushd workspace

    local lto=$( [[ $1 ]] && echo "$1" || echo 'thin' )

    if [[ -f './kernel_platform/build_with_bazel.py' ]]; then
        ./kernel_platform/oplus/bazel/oplus_modules_variant.sh $CPU_CODENAME gki
        ./kernel_platform/build_with_bazel.py --lto=thin -t $CPU_CODENAME gki
    else
        # Hack to bypass asking for lto and the "build target" selection.
        # See kernel_platform/oplus/build/oplus_build_kernel.sh
        # and kernel_platform/oplus/build/oplus_setup.sh
        echo -e "$lto\nall" | ./kernel_platform/oplus/build/oplus_build_kernel.sh $CPU_CODENAME gki
    fi

    if [[ ! -f 'out/dist/Image' ]]; then
        echo 'Build failed!'
        exit 1
    fi

    local kernel_version=`strings out/dist/Image | grep -oP '(?<=Linux version )\d\S+'`

    echo "Kernel version: $kernel_version"

    [[ $SUKISU_KPM == true ]] && patch_kpm

    popd

    echo Build successful
}

main $1
