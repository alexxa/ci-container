FROM registry.access.redhat.com/ubi10-minimal:10.0-1755721767

ARG UID=1001

RUN microdnf -y --nodocs install \
        git \
        jq \
        nc \
        podman \
        socat \
    && microdnf clean all

ADD files/bin /usr/local/bin

ENV HOME=/var/lib/ci

RUN useradd --key HOME_MODE=0775 --uid ${UID} --gid 0 --create-home --home-dir "${HOME}" ci

USER ci
WORKDIR $HOME
