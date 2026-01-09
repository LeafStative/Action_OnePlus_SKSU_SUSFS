#!/usr/bin/bash

check_environment() {
    local result=0
    if ! which python3 > /dev/null 2>&1; then
        echo 'Python3 is not installed.'
        result=1
    fi

    if ! which git > /dev/null 2>&1; then
        echo 'Git is not installed.'
        result=1
    fi

    if ! which curl > /dev/null 2>&1; then
        echo 'Curl is not installed.'
        result=1
    fi

    if ! which unzip > /dev/null 2>&1; then
        echo 'Unzip is not installed.'
        result=1
    fi

    if ! which jq > /dev/null 2>&1; then
        echo 'Jq is not installed.'
        result=1
    fi

    if [[ $result -ne 0 ]]; then
        echo 'Please install the missing dependencies.'
        return $result
    fi

    return 0
}

check_kpm_support() {
    case "$1" in
        full|compile-only|none)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_sukisu_hook() {
    case "$1" in
        susfs|manual|kprobes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

extract_gki_abi() {
    local kernel_source=$1

    for f in "$kernel_source/build.config.constants" "$kernel_source/build.config.common"; do
        if [[ -f $f ]]; then
            local branch=$(grep -m1 '^BRANCH=' "$f" | cut -d= -f2)
            [[ $branch ]] && break
        fi
    done

    echo $branch

    [[ $branch ]] || return 1
}

patch_kpm() {
    local patch_binary="$1"
    local image_dir="$2"

    echo 'KernelPatch module enabled, patching kernel image'

    cp "$patch_binary" "$image_dir"
    pushd $image_dir

    chmod a+x ./patch_linux
    ./patch_linux

    mv Image Image.bak
    mv oImage Image

    echo 'Kernel image patched'

    popd
}
