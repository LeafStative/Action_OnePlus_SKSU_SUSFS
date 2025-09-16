#!/usr/bin/bash

help_message() {
    cat << EOF
USAGE: $0 [OPTION ...]
    Init Android kernel compilation workspace.

    Options:
      -h, --help                   Show this help message and exit.
      -r, --repo                   Kernel source repo (default LineageOS/android_kernel_oneplus_sdm845).
      -b, --branch                 Kernel source repo branch (optional).
      -S, --kernel-suffix          Custom Kernel suffix (optional).
      -k, --sukisu                 (bool) Integrate SukiSU-Ultra to kernel (default false).
      -d, --sukisu-debug           (bool) Enable SukiSU-Ultra debug mode (default false).
      -K, --sukisu-kpm             (bool) Enable KernelPatch module support (default true).
      -v, --sukisu-version         Custom SukiSU-Ultra version string (optional).
      -s, --susfs                  (bool) Enable susfs integration (default true).
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

parse_args() {
    local args=`getopt -o hr:b:S:kdK::v:s:: \
    -l help,repo:,branch:,kernel-suffix:,sukisu,sukisu-debug,sukisu-kpm::,sukisu-version:,susfs:: \
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
                KERNEL_REPO="$2"
                shift 2
                ;;
            -b|--branch)
                KERNEL_BRANCH="$2"
                shift 2
                ;;
            -S|--kernel-suffix)
                KERNEL_SUFFIX="$2"
                shift 2
                ;;
            -k|--sukisu)
                SUKISU=true
                shift 1
                ;;
            -d|--sukisu-debug)
                SUKISU_DEBUG=true
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
    if [[ $KERNEL_REPO ]]; then
        echo "KERNEL_REPO='$KERNEL_REPO'" >> repo.conf
    fi

    if [[ $KERNEL_BRANCH ]]; then
        echo "KERNEL_BRANCH='$KERNEL_BRANCH'" >> repo.conf
    fi

    echo "KERNEL_SUFFIX='$KERNEL_SUFFIX'" >> repo.conf

    if [[ $SUKISU == true ]]; then
        echo -e '\nSUKISU=true' >> repo.conf

        if [[ $SUKISU_DEBUG == true ]]; then
            echo "SUKISU_DEBUG=$SUKISU_DEBUG" >> repo.conf
        fi

        if [[ $SUKISU_KPM ]]; then
            echo "SUKISU_KPM=$SUKISU_KPM" >> repo.conf
        fi

        if [[ $SUKISU_VER ]]; then
            echo "SUKISU_VER=$SUKISU_VER" >> repo.conf
        fi

        if [[ $SUSFS_ENABLED ]]; then
            echo "SUSFS_ENABLED=$SUSFS_ENABLED" >> repo.conf
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

    if [[ $SUKISU != true ]]; then
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
    script_dir=`readlink -f "$script_dir/../.."`
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
