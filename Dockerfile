# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG

ARG GO_IMAGE_NAME
ARG GO_IMAGE_TAG
FROM ${GO_IMAGE_NAME}:${GO_IMAGE_TAG} AS builder

ARG NVM_VERSION
ARG NVM_SHA256_CHECKSUM
ARG IMAGE_NODEJS_VERSION
ARG ALERTMANAGER_VERSION

COPY scripts/start-alertmanager.sh /scripts/
COPY patches /patches

# hadolint ignore=DL4006,SC3009,SC3040
RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    && homelab install build-essential git \
    && homelab install-node \
        ${NVM_VERSION:?} \
        ${NVM_SHA256_CHECKSUM:?} \
        ${IMAGE_NODEJS_VERSION:?} \
    # Download alertmanager repo. \
    && homelab download-git-repo \
        https://github.com/prometheus/alertmanager \
        ${ALERTMANAGER_VERSION:?} \
        /root/alertmanager-build \
    && pushd /root/alertmanager-build \
    # Apply the patches. \
    && (find /patches -iname *.diff -print0 | sort -z | xargs -0 -n 1 patch -p2 -i) \
    && source /opt/nvm/nvm.sh \
    # Build alertmanager. \
    && make build \
    && popd \
    # Copy the build artifacts. \
    && mkdir -p /output/{bin,scripts,configs} \
    && cp /root/alertmanager-build/{alertmanager,amtool} /output/bin \
    && cp /root/alertmanager-build/examples/ha/alertmanager.yml /output/configs \
    && cp /scripts/* /output/scripts

FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG ALERTMANAGER_VERSION

# hadolint ignore=DL4006,SC2086,SC3009
RUN --mount=type=bind,target=/alertmanager-build,from=builder,source=/output \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    && mkdir -p /opt/alertmanager-${ALERTMANAGER_VERSION:?}/bin /data/alertmanager/{config,data} \
    && cp /alertmanager-build/bin/alertmanager /opt/alertmanager-${ALERTMANAGER_VERSION:?}/bin \
    && cp /alertmanager-build/bin/amtool /opt/alertmanager-${ALERTMANAGER_VERSION:?}/bin \
    && cp /alertmanager-build/configs/alertmanager.yml /data/alertmanager/config/alertmanager.yml \
    && ln -sf /opt/alertmanager-${ALERTMANAGER_VERSION:?} /opt/alertmanager \
    && ln -sf /opt/alertmanager/bin/alertmanager /opt/bin/alertmanager \
    && ln -sf /opt/alertmanager/bin/amtool /opt/bin/amtool \
    # Copy the start-alertmanager.sh script. \
    && cp /alertmanager-build/scripts/start-alertmanager.sh /opt/alertmanager/ \
    && ln -sf /opt/alertmanager/start-alertmanager.sh /opt/bin/start-alertmanager \
    # Set up the permissions. \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} /opt/alertmanager-${ALERTMANAGER_VERSION:?} /opt/alertmanager /opt/bin/{alertmanager,amtool,start-alertmanager} /data/alertmanager \
    # Clean up. \
    && homelab cleanup

# Expose the HTTP server port used by Prometheus.
EXPOSE 9093

# Use the healthcheck command part of alertmanager as the health checker.
HEALTHCHECK \
    --start-period=15s --interval=30s --timeout=3s \
    CMD homelab healthcheck-service http://localhost:9093/-/healthy

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-alertmanager"]
STOPSIGNAL SIGTERM
