#!/usr/bin/bash

main() {
    source repo.conf

    local lto=$( [[ $1 ]] && echo "$1" || echo 'thin' )

    if [[ $BAZEL_BUILD == 'true' ]]; then
        ./kernel_platform/build_with_bazel.py -t $CPU_CODENAME gki
    else
        # Hack to bypass asking for lto and the "build target" selection.
        # See kernel_platform/oplus/build/oplus_build_kernel.sh
        # and kernel_platform/oplus/build/oplus_setup.sh
        echo -e "$lto\nall" | ./kernel_platform/oplus/build/oplus_build_kernel.sh $CPU_CODENAME gki
    fi
}

main $1
