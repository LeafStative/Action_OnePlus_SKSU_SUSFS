#!/usr/bin/bash

main() {
    mkdir -p workspace/artifacts
    pushd workspace

    echo "Downloading ReSukiSU manager apks..."

    curl -LO https://nightly.link/ReSukiSU/ReSukiSU/workflows/build-manager/main/Manager-release.zip
    unzip -od artifacts Manager-release.zip

    popd

    echo "ReSukiSU manager apks saved to '$(realpath artifacts)'"
}

main
