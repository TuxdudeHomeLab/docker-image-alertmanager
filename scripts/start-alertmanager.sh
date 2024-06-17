#!/usr/bin/env bash
set -E -e -o pipefail

alertmanager_config="/data/alertmanager/config/alertmanager.yml"

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

start_alertmanager() {
    echo "Starting Alertmanager ..."
    echo

    local config="${ALERTMANAGER_CONFIG:-${alertmanager_config:?}}"
    unset ALERTMANAGER_CONFIG
    unset alertmanager_config

    exec alertmanager \
        --config.file ${config:?} \
        --storage.path /data/alertmanager/data \
        "$@"
}

set_umask
start_alertmanager "$@"
