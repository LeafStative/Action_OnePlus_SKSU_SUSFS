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
      -n, --kernel-name            Custom Kernel name.
      -c, --codename               CPU code name.
      -z, --zram                   (bool) Integrate ZRAM patches (default false).
      -S, --sched                  (bool) Integrate sched_ext to kernel (default false, SoCs other than sm8750 may not work).
      -k, --sukisu                 (bool) Integrate SukiSU-Ultra to kernel (default false).
      -K, --sukisu-kpm             (bool) Enable KernelPatch module support (default true).
      -v, --sukisu-version         Custom SukiSU-Ultra version string (optional).
      -s, --susfs                  (bool) Enable susfs integration (default true).
      -m, --sukisu-manual-hooks    (bool) Implementation using manual hooks instead of kprobes.
                                   Cannot work together with SUSFS (default false).
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
    local args=$(getopt -o hr:b:f:n:c:zSkK::v:ms:: \
    -l help,repo:,branch:,file:,kernel-name:,codename:,zram,sched,sukisu,sukisu-kpm::,sukisu-version:,sukisu-manual-hooks,susfs:: \
    -n "$0" -- "$@")

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
            -S|--sched)
                SCHED_ENABLED=true
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
                        echo "Invalid KPM value '$2'."
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
    [[ $REPO_URL ]] && echo "REPO_URL='$REPO_URL'" >> repo.conf

    cat >> repo.conf << EOF
REPO_BRANCH='$REPO_BRANCH'
MANIFEST_FILE='$MANIFEST_FILE'
KERNEL_NAME='$KERNEL_NAME'
CPU_CODENAME=$CPU_CODENAME
EOF

    [[ $ZRAM_ENABLED == true ]] && echo 'ZRAM_ENABLED=true' >> repo.conf
    [[ $SCHED_ENABLED == true ]] && echo 'SCHED_ENABLED=true' >> repo.conf

    if [[ $SUKISU == true ]]; then
        echo -e '\nSUKISU=true' >> repo.conf

        [[ $SUKISU_KPM ]] && echo "SUKISU_KPM=$SUKISU_KPM" >> repo.conf
        [[ $SUKISU_VER ]] && echo "SUKISU_VER=$SUKISU_VER" >> repo.conf
        [[ $SUSFS_ENABLED ]] && echo "SUSFS_ENABLED=$SUSFS_ENABLED" >> repo.conf
        [[ $SUKISU_MANUAL_HOOKS == true ]] && echo 'SUKISU_MANUAL_HOOKS=true' >> repo.conf
    fi
}

check_args() {
    local result=0
    local susfs_status=$( [[ ! $SUSFS_ENABLED || $SUSFS_ENABLED == true ]] && echo true || echo false )

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

        if [[ $SUKISU_MANUAL_HOOKS ]]; then
            echo "SukiSU-Ultra manual hooks specified, but SukiSU-Ultra not enabled, ignored."
            unset SUKISU_MANUAL_HOOKS
        fi
    elif [[ $susfs_status == true && $SUKISU_MANUAL_HOOKS == true ]]; then
        echo "SUSFS cannot work with SukiSU-Ultra manual hooks implementation."
        result=1
    fi

    [[ $result -ne 0 ]] && echo "Try '$0 --help' for more information."

    return $result
}

main() {
    parse_args $@

    check_args || exit 1
    check_environment || exit 1

    local script_dir=$(dirname $(realpath "$0"))

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
