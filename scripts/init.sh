#!/usr/bin/bash

help_message() {
    cat << EOF
USAGE: $0 [OPTION ...]
    Init Android kernel compilation workspace.

    Options:
      -h, --help                   Show this help message and exit.
      -r, --repo                   Kernel manifest repo url (default OnePlusOSS/kernel_manifest).
      -b, --branch                 Kernel manifest repo branch.
      -f, --file                   Kernel manifest file name.
      -g, --gki-abi                Kernel GKI ABI (required if susfs or zram enabled).
      -n, --kernel-name            Custom Kernel name.
      -c, --codename               CPU code name.
      -z, --zram                   (bool) Integrate ZRAM patches (default false)
      -k, --sukisu                 (bool) Integrate SukiSU-Ultra to kernel (default false)
      -K, --sukisu-kpm             (bool) Enable KernelPatch module support (default true)
      -v, --sukisu-version         Custom SukiSU-Ultra version string (optional).
      -m, --sukisu-manual-hooks    (bool) Implementation using manual hooks instead of kprobes (default false, susfs required).
      -s, --susfs                  (bool) Enable susfs integration (default true)
EOF
}

check_environment() {
    local result=0
    if ! which python3 > /dev/null 2>&1; then
        echo 'Python3 is not installed.'
        result=1
    fi

    if ! which git > /dev/null 2>&1; then
        echo 'Git is not installed.'
        result=1
    fi

    if ! which curl > /dev/null 2>&1; then
        echo 'Curl is not installed.'
        result=1
    fi

    if ! which unzip > /dev/null 2>&1; then
        echo 'Unzip is not installed.'
        result=1
    fi

    if ! which jq > /dev/null 2>&1; then
        echo 'Jq is not installed.'
        result=1
    fi

    if [[ $result -ne 0 ]]; then
        echo 'Please install the missing dependencies.'
        return $result
    fi

    return 0
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
    local args=`getopt -o hr:b:f:g:n:c:zkK::v:ms:: \
    -l help,repo:,branch:,file:,gki-abi:,kernel-name:,codename:,zram,sukisu,sukisu-kpm::,sukisu-version:,sukisu-manual-hooks,susfs:: \
    -n "$0" -- "$@"`

    if ! eval set -- "$args"; then
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
            -z|--zram)
                ZRAM_ENABLED=true
                shift 1
                ;;
            -k|--sukisu)
                SUKISU=true
                shift 1
                ;;
            -K|--sukisu-kpm)
                case "$2" in
                    ''|true)
                        SUKISU_KPM=true
                        shift 2
                        ;;
                    false)
                        SUKISU_KPM=false
                        shift 2
                        ;;
                    *)
                        echo "Invalid susfs status '$2'."
                        exit 1
                        ;;
                esac
                ;;
            -v|--sukisu-version)
                SUKISU_VER="$2"
                shift 2
                ;;
            -m|--sukisu-manual-hooks)
                SUKISU_MANUAL_HOOKS=true
                shift 1
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

    if [[ $GKI_ABI ]]; then
        echo "GKI_ABI=$GKI_ABI" >> repo.conf
    fi

    if [[ $ZRAM_ENABLED == true ]]; then
        echo 'ZRAM_ENABLED=true' >> repo.conf
    fi

    if [[ $SUKISU == true ]]; then
        echo -e '\nSUKISU=true' >> repo.conf

        if [[ $SUKISU_KPM ]]; then
            echo "SUKISU_KPM=$SUKISU_KPM" >> repo.conf
        fi

        if [[ $SUKISU_VER ]]; then
            echo "SUKISU_VER=$SUKISU_VER" >> repo.conf
        fi

        if [[ $SUSFS_ENABLED ]]; then
            echo "SUSFS_ENABLED=$SUSFS_ENABLED" >> repo.conf
        fi

        if [[ $SUKISU_MANUAL_HOOKS == true ]]; then
            echo 'SUKISU_MANUAL_HOOKS=true' >> repo.conf
        fi
    fi
}

check_args() {
    local result=0

    if [[ ! $SUSFS_ENABLED || $SUSFS_ENABLED == true ]]; then
        local susfs_status=true
    else
        local susfs_status=false
    fi

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

    local gki_required=$( [[ $ZRAM_ENABLED || ( $SUKISU == true && $susfs_status == true ) ]] && echo true || echo false )
    if [[ $GKI_ABI ]]; then
        if [[ $gki_required == true ]]; then
            if ! check_gki_abi "$GKI_ABI"; then
                echo "Invalid GKI ABI '$GKI_ABI'."
                result=1
            fi
        else
            echo 'GKI ABI specified, but ZRAM or SukiSU-Ultra with SUSFS not enabled, ignored.'
            unset GKI_ABI
        fi
    elif [[ $gki_required == true ]]; then
        echo 'ZRAM or SukiSU-Ultra with SUSFS enabled, but no GKI ABI specified.'
        result=1
    fi

    if [[ $SUKISU == true ]]; then
        if [[ $SUKISU_MANUAL_HOOKS == true && $susfs_status != true ]]; then
            echo 'SUSFS is required by SukiSU-Ultra manual hooks, but it is not enabled.'
            result=1
        fi
    else
        if [[ $SUKISU_KPM ]]; then
            echo "KernelPatch module support enabled, but SukiSU-Ultra not enabled, ignored."
            unset SUKISU_VER
        fi

        if [[ $SUKISU_VER ]]; then
            echo "Custom SukiSU-Ultra version '$SUKISU_VER' specified, but SukiSU-Ultra not enabled, ignored."
            unset SUKISU_VER
        fi

        if [[ $SUSFS_ENABLED ]]; then
            echo "SUSFS status manually specified, but SukiSU-Ultra not enabled, ignored."
            unset SUSFS_ENABLED
        fi

        if [[ $SUKISU_MANUAL_HOOKS ]]; then
            echo "SukiSU-Ultra manual hooks specified, but SukiSU-Ultra not enabled, ignored."
            unset SUKISU_MANUAL_HOOKS
        fi
    fi

    if [[ $result -ne 0 ]]; then
        echo "Try '$0 --help' for more information."
    fi

    return $result
}

main() {
    parse_args $@

    if ! check_args; then
        exit 1
    fi

    if ! check_environment; then
        exit 1
    fi

    local script_dir=`dirname $(realpath "$0")`

    if [[ ! -f 'tools/repo' || ! -f 'tools/magiskboot' ]]; then
        echo "Tools not found, downloading..."
        
        if ! "$script_dir/lib/setup_tools.sh"; then
            echo "Failed to setup tools."
            result=1
        fi
    fi

    write_config
    echo 'Configuration written to repo.conf'
}

main $@
