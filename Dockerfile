# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-scripts

COPY scripts/start-alertmanager.sh /scripts/

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

SHELL ["/bin/bash", "-c"]

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG ALERTMANAGER_VERSION

# hadolint ignore=DL4006,SC2086
RUN --mount=type=bind,target=/scripts,from=with-scripts,source=/scripts \
    set -E -e -o pipefail \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    # Download and install the release. \
    && mkdir -p /tmp/alertmanager \
    && PKG_ARCH="$(dpkg --print-architecture)" \
    && curl \
        --silent \
        --fail \
        --location \
        --remote-name \
        --output-dir /tmp/alertmanager \
        https://github.com/prometheus/alertmanager/releases/download/${ALERTMANAGER_VERSION:?}/alertmanager-${ALERTMANAGER_VERSION#v}.linux-${PKG_ARCH:?}.tar.gz \
    && curl \
        --silent \
        --fail \
        --location \
        --remote-name \
        --output-dir /tmp/alertmanager \
        "https://github.com/prometheus/alertmanager/releases/download/${ALERTMANAGER_VERSION:?}/sha256sums.txt" \
    && pushd /tmp/alertmanager \
    && grep "alertmanager-${ALERTMANAGER_VERSION#v}.linux-${PKG_ARCH:?}.tar.gz" sha256sums.txt | sha256sum -c \
    && tar xvf alertmanager-${ALERTMANAGER_VERSION#v}.linux-${PKG_ARCH:?}.tar.gz \
    && pushd alertmanager-${ALERTMANAGER_VERSION#v}.linux-${PKG_ARCH:?} \
    && mkdir -p /opt/alertmanager-${ALERTMANAGER_VERSION:?}/bin /data/alertmanager/{config,data} \
    && mv alertmanager /opt/alertmanager-${ALERTMANAGER_VERSION:?}/bin \
    && mv amtool /opt/alertmanager-${ALERTMANAGER_VERSION:?}/bin \
    && mv alertmanager.yml /data/alertmanager/config/alertmanager.yml \
    && ln -sf /opt/alertmanager-${ALERTMANAGER_VERSION:?} /opt/alertmanager \
    && ln -sf /opt/alertmanager/bin/alertmanager /opt/bin/alertmanager \
    && ln -sf /opt/alertmanager/bin/amtool /opt/bin/amtool \
    && popd \
    && popd \
    # Copy the start-alertmanager.sh script. \
    && cp /scripts/start-alertmanager.sh /opt/alertmanager/ \
    && ln -sf /opt/alertmanager/start-alertmanager.sh /opt/bin/start-alertmanager \
    # Set up the permissions. \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} /opt/alertmanager-${ALERTMANAGER_VERSION:?} /opt/alertmanager /opt/bin/{alertmanager,amtool,start-alertmanager} /data/alertmanager \
    # Clean up. \
    && rm -rf /tmp/alertmanager \
    && homelab cleanup

# Expose the HTTP server port used by Prometheus.
EXPOSE 9093

# Use the healthcheck command part of alertmanager as the health checker.
HEALTHCHECK --start-period=1m --interval=30s --timeout=3s CMD curl --silent --fail --location http://localhost:9093/-/healthy

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-alertmanager"]
STOPSIGNAL SIGTERM
