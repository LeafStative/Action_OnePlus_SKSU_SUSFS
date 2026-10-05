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
      -e, --bbr-ecn                (bool) Enable BBR+ECN (default false).
      -n, --netfilter              (bool) Integrate Netfilter patches (default false).
      -S, --sched                  (bool) Integrate sched_ext to kernel (default false, SoCs other than sm8750 may not work).
      -B, --baseband-guard         (bool) Integrate Baseband-guard to kernel (default false).
      -k, --bakasu                 (bool) Integrate BakaSU to kernel (default false).
      -v, --bakasu-version <name>  Custom BakaSU version string (optional).
      -H, --bakasu-hook <hook>     BakaSU hook type selection, available options:
                                     susfs (default)
                                     manual
                                     tracepoint
EOF
}

parse_args() {
    local args=$(getopt -o hr:b:f:s:c:zenSBkv:H: \
    -l help,repo:,branch:,file:,kernel-suffix:,codename:,zram,bbr-ecn,netfilter,sched,baseband-guard,bakasu,bakasu-version:,bakasu-hook: \
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
            -e|--bbr-ecn)
                BBR_ECN_ENABLED=true
                shift 1
                ;;
            -n|--netfilter)
                NETFILTER_ENABLED=true
                shift 1
                ;;
            -S|--sched)
                SCHED_ENABLED=true
                shift 1
                ;;
            -B|--baseband-guard)
                BASEBAND_GUARD_ENABLED=true
                shift 1
                ;;
            -k|--bakasu)
                BAKASU=true
                shift 1
                ;;
            -v|--bakasu-version)
                BAKASU_VER="$2"
                shift 2
                ;;
            -H|--bakasu-hook)
                BAKASU_HOOK="$2"
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
    [[ $BBR_ECN_ENABLED == true ]] && echo 'BBR_ECN_ENABLED=true' >> repo.conf
    [[ $NETFILTER_ENABLED == true ]] && echo 'NETFILTER_ENABLED=true' >> repo.conf
    [[ $SCHED_ENABLED == true ]] && echo 'SCHED_ENABLED=true' >> repo.conf
    [[ $BASEBAND_GUARD_ENABLED == true ]] && echo 'BASEBAND_GUARD_ENABLED=true' >> repo.conf

    if [[ $BAKASU == true ]]; then
        echo -e '\nBAKASU=true' >> repo.conf

        [[ $BAKASU_VER ]] && echo "BAKASU_VER=$BAKASU_VER" >> repo.conf
        [[ $BAKASU_HOOK ]] && echo "BAKASU_HOOK=$BAKASU_HOOK" >> repo.conf
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

    if [[ $BAKASU != true ]]; then
        if [[ $BAKASU_VER ]]; then
            echo "Custom BakaSU version '$BAKASU_VER' specified, but BakaSU not enabled, ignored."
            unset BAKASU_VER
        fi

        if [[ $BAKASU_HOOK ]]; then
            echo "BakaSU hook type '$BAKASU_HOOK' specified, but BakaSU not enabled, ignored."
            unset BAKASU_HOOK
        fi
    else
        if [[ $BAKASU_HOOK ]] && ! check_bakasu_hook "$BAKASU_HOOK"; then
            echo "Invalid BakaSU hook type '$BAKASU_HOOK'."
            result=1
        fi
    fi

    [[ $result -ne 0 ]] && echo "Try '$0 --help' for more information."

    return $result
}

main() {
    local script_dir=$(dirname $(realpath "$0"))
    source "$script_dir/lib/utils.sh"

    parse_args $@

    check_args || exit 1
    check_environment dos2unix || exit 1

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
