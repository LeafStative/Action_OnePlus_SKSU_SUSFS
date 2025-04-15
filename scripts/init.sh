#!/usr/bin/bash

help_message() {
    cat << EOF
USAGE: $0 [OPTION ...]
    Init Android kernel compilation workspace.

    Options:
      -h, --help             Show this help message and exit.
      -r, --repo             Kernel manifest repo url (default OnePlusOSS/kernel_manifest).
      -b, --branch           Kernel manifest repo branch.
      -f, --file             Kernel manifest file name.
      -g, --gki-abi          Kernel GKI ABI (required if susfs enabled).
      -n, --kernel-name      Custom Kernel name.
      -c, --codename         CPU code name.
      -k, --kernelsu         KernelSU variant (optional, accepted Official, KSUN, MKSU, RKSU, SKSU).
      -B, --kernelsu-branch  KernelSU git repo branch (default main).
      -v, --kernelsu-version Custom KernelSU version string (optional).
      -s, --susfs            (bool) Enable susfs integration (default true)
      -z, --bazel            (bool) Build with bazel (default false)
EOF
}

check_environment() {
    which python3 > /dev/null 2>&1
    local python3_exists=$?

    which git > /dev/null 2>&1
    local git_exists=$?

    which curl > /dev/null 2>&1
    local curl_exists=$?

    which unzip > /dev/null 2>&1
    local unzip_exists=$?

    which jq > /dev/null 2>&1
    local jq_exists=$?

    local result=0
    if [[ $python3_exists -ne 0 ]]; then
        echo "Python3 is not installed."
        result=1
    fi

    if [[ $git_exists -ne 0 ]]; then
        echo "Git is not installed."
        result=1
    fi

    if [[ $curl_exists -ne 0 ]]; then
        echo "Curl is not installed."
        result=1
    fi

    if [[ $unzip_exists -ne 0 ]]; then
        echo "Unzip is not installed."
        result=1
    fi

    if [[ $jq_exists -ne 0 ]]; then
        echo "Jq is not installed."
        result=1
    fi

    if [[ $result -ne 0 ]]; then
        echo "Please install the missing dependencies."
        return $result
    fi

    which python > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        python() {
            python3 $@
        }
        export -f python
    fi

    return 0
}

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

setup_tools() {
    mkdir setup_workdir

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

check_ksu_variant() {
    local ksu=${1,,}
    case "$ksu" in
        official|ksun|mksu|rksu|sksu)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_ksu_branch() {
    case "$1" in
        tag|main)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_gki_abi() {
    case "$1" in
        android12-5.10|android13-5.10|android13-5.15|android14-5.15|android14-6.1|android15-6.6)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

parse_args() {
    local args=`getopt -o hr:b:f:g:n:c:k:B:v:s::z \
    -l help,repo:,branch:,file:,gki-abi:,kernel-name:,codename:,kernelsu:,kernelsu-branch:,kernelsu-version:,susfs::,bazel \
    -n "$0" -- "$@"`

    eval set -- "$args"
    
    if [[ $? -ne 0 ]]; then
        help_message
        exit 1
    fi

    while true
    do
        case "$1" in
            -h|--help)
                help_message
                exit 0
                ;;
            -r|--repo)
                REPO_URL="$2"
                shift 2
                ;;
            -b|--branch)
                REPO_BRANCH="$2"
                shift 2
                ;;
            -f|--file)
                MANIFEST_FILE="$2"
                shift 2
                ;;
            -g|--gki-abi)
                GKI_ABI="$2"
                shift 2
                ;;
            -n|--kernel-name)
                KERNEL_NAME="$2"
                shift 2
                ;;
            -c|--codename)
                CPU_CODENAME="$2"
                shift 2
                ;;
            -k|--kernelsu)
                KSU="$2"
                shift 2
                ;;
            -v|--kernelsu-version)
                KSU_VER="$2"
                shift 2
                ;;
            -B|--kernelsu-branch)
                KSU_BRANCH="$2"
                shift 2
                ;;
            -s|--susfs)
                case "$2" in
                    ''|true)
                        SUSFS_ENABLED=true
                        shift 2
                        ;;
                    false)
                        SUSFS_ENABLED=false
                        shift 2
                        ;;
                    *)
                        echo "Invalid susfs status '$2'."
                        exit 1
                        ;;
                esac
                ;;
            -z|--bazel)
                BAZEL_BUILD=true
                shift 1
                ;;

            --)
                shift
                break
                ;;
            *)
                echo 'Unknown error'
                exit 1
                ;;
        esac
    done
}

write_config() {
    echo -n > repo.conf
    if [[ $REPO_URL ]]; then
        echo "REPO_URL='$REPO_URL'" >> repo.conf
    fi

    cat >> repo.conf << EOF
REPO_BRANCH='$REPO_BRANCH'
MANIFEST_FILE='$MANIFEST_FILE'
KERNEL_NAME='$KERNEL_NAME'
CPU_CODENAME=$CPU_CODENAME
EOF

    if [[ $KSU ]]; then
        echo -e "\nKSU=${KSU,,}" >> repo.conf

        if [[ $KSU_VER ]]; then
            echo "KSU_VER=$KSU_VER" >> repo.conf
        fi

        if [[ $KSU_BRANCH ]]; then
            echo "KSU_BRANCH=$KSU_BRANCH" >> repo.conf
        fi

        if [[ $SUSFS_ENABLED ]]; then
            echo "SUSFS_ENABLED=$SUSFS_ENABLED" >> repo.conf
        fi

        if [[ ! $SUSFS_ENABLED || $SUSFS_ENABLED == true ]]; then
            echo "SUSFS_BRANCH=gki-$GKI_ABI" >> repo.conf
        fi
    fi

    if [[ $BAZEL_BUILD == true ]]; then
        echo 'BAZEL_BUILD=true' >> repo.conf
    fi
}

check_args() {
    local result=0

    if [[ ! $REPO_BRANCH ]]; then
        echo 'No repo branch specified.'
        result=1
    fi

    if [[ ! $MANIFEST_FILE ]]; then
        echo 'No manifest file name specified.'
        result=1
    fi

    if [[ ! $KERNEL_NAME ]]; then
        echo 'No kernel name specified.'
        result=1
    fi

    if [[ ! $CPU_CODENAME ]]; then
        echo 'No cpu codename specified.'
        result=1
    fi

    if [[ $KSU ]]; then
        check_ksu_variant "$KSU"
        if [[ $? -ne 0 ]]; then
            echo "Invalid KernelSU variant '$KSU'."
            result=1
        fi

        check_ksu_branch "$KSU_BRANCH"
        if [[ $KSU_BRANCH && $? -ne 0 ]]; then
            echo "Invalid KernelSU branch '$KSU_BRANCH'."
            result=1
        fi

        if [[ ! $SUSFS_ENABLED || $SUSFS_ENABLED == true ]]; then
            if [[ ! $GKI_ABI ]]; then
                echo 'No GKI ABI specified.'
                result=1
            else
                check_gki_abi "$GKI_ABI"
                if [[ $? -ne 0 ]]; then
                    echo "Invalid GKI ABI '$GKI_ABI'."
                    result=1
                fi
            fi
        else
            if [[ $GKI_ABI ]]; then
                echo 'GKI ABI specified, but susfs not enabled, ignored.'
            fi
        fi
    else
        if [[ $KSU_VER ]]; then
            echo "Custom KernelSU version '$KSU_VER' specified, but KernelSU not enabled, ignored."
        fi

        if [[ $KSU_BRANCH ]]; then
            echo "Custom KernelSU repo branch '$KSU_BRANCH' specified, but KernelSU not enabled, ignored."
        fi

        if [[ $SUSFS_ENABLED ]]; then
            echo "Susfs status manually specified, but KernelSU not enabled, ignored."
        fi

        if [[ $GKI_ABI ]]; then
            echo 'GKI ABI specified, but KernelSU not enabled, ignored.'
        fi
    fi

    if [[ $result -ne 0 ]]; then
        echo "Try '$0 --help' for more information."
    fi

    return $result
}

main() {
    parse_args $@
    check_args
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    check_environment
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    if [[ ! -f 'tools/repo' || ! -f 'tools/magiskboot' ]]; then
        echo "Tools not found, downloading..."
        
        if [[ ! -d tools ]]; then
            mkdir tools
        fi

        setup_tools
        if [[ $? -ne 0 ]]; then
            echo "Failed to setup tools."
            result=1
        fi
    fi

    write_config
    echo 'Configuration written to repo.conf'
}

main $@
