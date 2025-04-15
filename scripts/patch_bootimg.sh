#!/usr/bin/bash

magiskboot=tools/magiskboot

main() {
    local stock_img=`realpath "$1"`
    if [[ ! -e $stock_img ]]; then
        echo "File '$stock_img' not exist!"
        exit 1
    fi

    mkdir magiskboot_workdir
    pushd magiskboot_workdir

    $magiskboot unpack "$stock_img"
    rm kernel
    cp ../out/dist/Image kernel
    $magiskboot repack "$stock_img" ../patched_boot.img

    popd

    rm -rf magiskboot_workdir
}

main $@
