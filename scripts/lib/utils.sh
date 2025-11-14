#!/usr/bin/bash

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
