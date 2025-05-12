#!/usr/bin/bash

main() {
    source repo.conf

    which python > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        python() {
            python3 $@
        }
        export -f python
    fi

    local lto=$( [[ $1 ]] && echo "$1" || echo 'thin' )

    if [[ $BAZEL_BUILD == 'true' ]]; then
        ./kernel_platform/build_with_bazel.py -t $CPU_CODENAME gki
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
    echo Build successful
}

main $1
