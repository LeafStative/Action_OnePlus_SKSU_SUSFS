#!/usr/bin/bash

help_message() {
    cat << EOF
USAGE: $0 [OPTION ...]
    Init Android kernel compilation workspace.

    Options:
      -h, --help                   Show this help message and exit.
      -r, --repo <repo_url>        Kernel manifest repo url (default OnePlusOSS/kernel_manifest).
      -b, --branch <branch_name>   Kernel manifest repo branch.
      -f, --file <filename>        Kernel manifest file name.
      -s, --kernel-suffix <suffix> Custom Kernel suffix.
      -c, --codename <codename>    CPU code name.
      -z, --zram                   (bool) Integrate ZRAM patches (default false).
      -S, --sched                  (bool) Integrate sched_ext to kernel (default false, SoCs other than sm8750 may not work).
      -k, --sukisu                 (bool) Integrate SukiSU-Ultra to kernel (default false).
      -K, --sukisu-kpm             (bool) Enable KernelPatch module support (default true).
      -v, --sukisu-version <name>  Custom SukiSU-Ultra version string (optional).
      -H, --sukisu-hook <hook>     Sukisu-Ultra hook type selection, available options:
                                     susfs (default)
                                     manual
                                     kprobes
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

check_sukisu_hook() {
    case "$1" in
        susfs|manual|kprobes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

parse_args() {
    local args=$(getopt -o hr:b:f:s:c:zSkK::v:H: \
    -l help,repo:,branch:,file:,kernel-suffix:,codename:,zram,sched,sukisu,sukisu-kpm::,sukisu-version:,sukisu-hook: \
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
            -s|--kernel-suffix)
                KERNEL_SUFFIX="$2"
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
            -H|--sukisu-hook)
                SUKISU_HOOK="$2"
                shift 2
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
KERNEL_SUFFIX='$KERNEL_SUFFIX'
CPU_CODENAME=$CPU_CODENAME
EOF

    [[ $ZRAM_ENABLED == true ]] && echo 'ZRAM_ENABLED=true' >> repo.conf
    [[ $SCHED_ENABLED == true ]] && echo 'SCHED_ENABLED=true' >> repo.conf

    if [[ $SUKISU == true ]]; then
        echo -e '\nSUKISU=true' >> repo.conf

        [[ $SUKISU_KPM ]] && echo "SUKISU_KPM=$SUKISU_KPM" >> repo.conf
        [[ $SUKISU_VER ]] && echo "SUKISU_VER=$SUKISU_VER" >> repo.conf
        [[ $SUKISU_HOOK ]] && echo "SUKISU_HOOK=$SUKISU_HOOK" >> repo.conf
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

    if [[ ! $KERNEL_SUFFIX ]]; then
        echo 'No kernel suffix specified.'
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

        if [[ $SUKISU_HOOK ]]; then
            echo "SukiSU-Ultra hook type '$SUKISU_HOOK' specified, but SukiSU-Ultra not enabled, ignored."
            unset SUKISU_HOOK
        fi
    elif [[ $SUKISU_HOOK ]] && ! check_sukisu_hook "$SUKISU_HOOK"; then
        echo "Invalid SukiSU-Ultra hook type '$SUKISU_HOOK'."
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
