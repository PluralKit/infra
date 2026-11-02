FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddyserver/replace-response

FROM caddy:2
RUN apk add --no-cache iptables ip6tables

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

COPY --from=tailscale/tailscale:latest /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale/tailscale:latest /usr/local/bin/tailscale /usr/local/bin/tailscale

COPY Caddyfile anycast.html stats.html cdn-index.html /etc/caddy/
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
