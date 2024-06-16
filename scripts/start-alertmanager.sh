#!/usr/bin/env bash
set -E -e -o pipefail

alertmanager_config="/data/alertmanager/config/alertmanager.yml"

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

start_alertmanager "$@"
