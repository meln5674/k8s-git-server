ARG PROXY_CACHE=
ARG BASE_IMAGE_REPO=docker.io/library/alpine
ARG BASE_IMAGE_TAG=3.17.2

ARG GOOS=linux
ARG GOARCH=amd64

FROM ${PROXY_CACHE}${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG}

RUN apk add openssh bash curl git
ARG GOOS
ARG GOARCH
ARG KUBECTL_MIRROR=https://dl.k8s.io/release
ARG KUBECTL_VERSION=v1.26.0
ARG KUBECTL_URL=${KUBECTL_MIRROR}/${KUBECTL_VERSION}/bin/${GOOS}/${GOARCH}/kubectl
RUN curl -L "${KUBECTL_URL}" > /usr/bin/kubectl && chmod +x /usr/bin/kubectl

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
