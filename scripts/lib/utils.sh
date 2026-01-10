#!/usr/bin/bash

check_environment() {
    set -- 'python3' 'git' 'curl' 'unzip' 'jq' "$@"

    local result=0
    for binary in "$@"; do
        if ! which "$binary" > /dev/null 2>&1; then
            echo "$binary is not installed."
            result=1
        fi
    done

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

extract_kernel_version() {
    local makefile="$1/Makefile"

    [[ ! -f $makefile ]] && return 1

    local version=$(grep -m1 '^VERSION =' "$makefile" | cut -d= -f2 | tr -d ' ')
    local patchlevel=$(grep -m1 '^PATCHLEVEL =' "$makefile" | cut -d= -f2 | tr -d ' ')
    local sublevel=$(grep -m1 '^SUBLEVEL =' "$makefile" | cut -d= -f2 | tr -d ' ')

    [[ ! $version || ! $patchlevel || ! $sublevel ]] && return 1

    echo "${version}.${patchlevel}.${sublevel}"
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
