#!/bin/sh

# originally by andrew-d

set -euo pipefail

log() {
    local if="$1"; shift
    echo "check-ready: $if:" $@
}

main() {
    local if="$1"

    local json tt
    local ready=y
    json="$(ip -json addr show "$if" | jq '.[0]')"

    tt="$(echo "$json" | jq -r .operstate)"
    if [[ $tt != "UP" ]]; then
        tt="$(echo "$json" | jq '.flags | contains(["UP"])')"
        if [[ $tt != "true" ]]; then
            log "$if" "not ready: $tt != UP and no UP flag"
            ready=n
        else
            log "$if" "link has UP flag"
        fi
    else
        log "$if" "link state is UP"
    fi

    local found4=n
    while read -r family addr; do
        if [[ $family = "inet" ]]; then
            log "$if" "found IPv4 address: $addr"
            found4=y
        fi
    done < <(echo "$json" | jq -r '.addr_info[] | [.family, .local] | @tsv')

    if [[ $found4 != y ]]; then
        log "$if" "no IPv4 address found"
        ready=n
    fi

    if [[ $ready = y ]]; then
        log "$if" "ready"
        exit 0
    fi

    log "$if" "not ready"
    exit 1
}

if [ "$1" == "main" ]; then main "$2"; fi

while true; do $0 main $1 && exit 0 || sleep 1; done
