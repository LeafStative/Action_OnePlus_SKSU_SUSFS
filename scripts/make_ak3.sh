#!/usr/bin/bash

main() {
    which zip > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Zip is not installed."
        exit 1
    fi

    if [[ ! -f 'out/dist/Image' ]]; then
        echo 'Kernel image not found! Please build the kernel first.'
        exit 1
    fi

    if [[ -f 'ak3.zip' ]]; then
        echo -n 'ak3.zip already exists. Do you want to overwrite it? (y/N): '

        local answer
        read -r answer
        if [[ $answer != 'y' && $answer != 'Y' ]]; then
            echo 'Exiting without overwriting.'
            exit 0
        fi

        local overwrite=true
    fi

    git clone https://github.com/Kernel-SU/AnyKernel3 --depth=1
    rm -rf ./AnyKernel3/.git
    cp out/dist/Image ./AnyKernel3/

    if [[ $overwrite == true ]]; then
        rm ak3.zip
    fi

    pushd AnyKernel3
    zip -rv ../ak3.zip *
    popd

    rm -rf ./AnyKernel3

    echo 'AnyKernel3 archive saved to ak3.zip'
}

main
