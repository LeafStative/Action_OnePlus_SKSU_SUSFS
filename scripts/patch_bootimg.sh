#!/usr/bin/bash

magiskboot=`realpath tools/magiskboot`

main() {
    local stock_img=`realpath "$1"`
    if [[ ! -e $stock_img ]]; then
        echo "File '$stock_img' not exist!"
        exit 1
    fi

    if [[ ! -f 'out/dist/Image' ]]; then
        echo 'Kernel image not found! Please build the kernel first.'
        exit 1
    fi

    mkdir -p magiskboot_workdir
    pushd magiskboot_workdir

    $magiskboot unpack "$stock_img"
    rm kernel
    cp ../out/dist/Image kernel
    $magiskboot repack "$stock_img" ../patched_boot.img

    popd

    rm -rf magiskboot_workdir

    echo 'Patched boot image saved to patched_boot.img'
}

main $@
