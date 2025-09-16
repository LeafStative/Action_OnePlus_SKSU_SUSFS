#!/usr/bin/bash

main() {
    which zip > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Zip is not installed."
        exit 1
    fi

    if [[ ! -d workspace ]]; then
        echo 'No workspace found. Please run download_src.sh to download source code first.'
        exit 1
    fi
    pushd workspace

    local image_path='android_kernel/out/arch/arm64/boot/Image'
    if [[ ! -f $image_path ]]; then
        echo 'Kernel image not found! Please build the kernel first.'
        exit 1
    fi

    if [[ -f 'AnyKernel3.zip' ]]; then
        echo -n 'AnyKernel3.zip already exists. Do you want to overwrite it? (y/N): '

        local answer
        read -r answer
        if [[ $answer != 'y' && $answer != 'Y' ]]; then
            echo 'Exiting without overwriting.'
            exit 0
        fi

        local overwrite=true
    fi

    if [[ -e './AnyKernel3' ]]; then
        echo 'AnyKernel3 exists, deleting'
        rm -rf ./AnyKernel3
    fi

    git clone https://github.com/Numbersf/AnyKernel3 --depth=1
    rm -rf ./AnyKernel3/.git
    cp $image_path ./AnyKernel3/

    if [[ $overwrite == true ]]; then
        rm AnyKernel3.zip
    fi

    pushd AnyKernel3
    zip -rv ../AnyKernel3.zip *
    popd

    popd

    echo 'AnyKernel3 archive saved to AnyKernel3.zip'
}

main
