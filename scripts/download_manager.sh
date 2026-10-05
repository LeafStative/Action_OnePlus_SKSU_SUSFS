#!/usr/bin/bash

main() {
    mkdir -p workspace/artifacts
    pushd workspace

    echo "Downloading BakaSU manager apks..."

    curl -LO https://nightly.link/Baka-SU/BakaSU/workflows/build-manager/main/Manager-release.zip
    unzip -od artifacts Manager-release.zip

    popd

    echo "BakaSU manager apks saved to '$(realpath artifacts)'"
}

main
