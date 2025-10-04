FROM alpine:latest

RUN apk add tailscale curl

ARG K3S_VERSION=v1.34.1%2Bk3s1

RUN curl -fsSL https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION/k3s > /usr/local/bin/k3s
RUN chmod +x /usr/local/bin/k3s

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
