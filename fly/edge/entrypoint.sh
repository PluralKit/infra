#!/bin/sh
set -e

export PATH=/bin:/usr/bin/:/sbin:/usr/sbin:/usr/local/bin

echo "nameserver 1.1.1.1" > /etc/resolv.conf

tailscaled &

ts_hostname="fly-${FLY_APP_NAME#pluralkit-}"
tailscale up \
  --auth-key=$TS_AUTHKEY \
  --hostname="$ts_hostname" \
  --accept-routes \
  --advertise-tags=tag:edge

tailscale wait

echo nameserver 100.100.100.100 > /etc/resolv.conf
exec caddy run --config /etc/caddy/Caddyfile
