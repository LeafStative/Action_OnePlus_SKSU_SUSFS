#!/usr/bin/bash

download_magiskboot() {
    local workdir=$1
    local urls=`curl 'https://api.github.com/repos/topjohnwu/Magisk/releases' | jq -r '.[0].assets[].browser_download_url'`
    for url in $urls; do
        if [[ $url =~ 'app-release.apk' || $url =~ Magisk-v.+\.apk ]]; then
            local apk_url=$url
            break
        fi
    done

    if [[ ! $apk_url ]]; then
        echo "Failed to find Magisk APK URL."
        return 1
    fi

    curl -Lo "$workdir/magisk.apk" $apk_url
    if [[ $? -ne 0 ]]; then
        echo "Failed to download Magisk APK."
        return 1
    fi

    unzip -jo "$workdir/magisk.apk" 'lib/x86_64/libmagiskboot.so' -d "$workdir"
    if [[ $? -ne 0 ]]; then
        echo "Failed to extract libmagiskboot.so from Magisk APK."
        return 1
    fi

    cp "$workdir/libmagiskboot.so" tools/magiskboot
    chmod a+x tools/magiskboot
}

download_repo() {
    local workdir=$1
    curl -Lo "$workdir/repo" https://storage.googleapis.com/git-repo-downloads/repo
    if [[ $? -ne 0 ]]; then
        echo "Failed to download repo tool."
        return 1
    fi

    cp "$workdir/repo" tools/repo
    chmod a+x tools/repo
}

main() {
    mkdir -p tools setup_workdir

    local result=0
    if [[ ! -f tools/magiskboot ]]; then
        download_magiskboot setup_workdir
        result=$?
    fi
    
    if [[ ! -f tools/repo ]]; then
        download_repo setup_workdir
        result=$?
    fi

    rm -rf setup_workdir

    return $result
}

main
