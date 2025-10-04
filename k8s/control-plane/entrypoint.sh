#!/bin/sh

export PATH=/bin:/usr/bin/:/sbin:/usr/sbin:/usr/local/bin

tailscaled &

tailscale up \
  --accept-routes \
  --hostname fly-k3s-sjc-cp \
  --authkey=$TS_AUTHKEY \
  --advertise-tags=tag:k8s-cp

echo "running k3s server"

# sleep inf

exec k3s server \
  --disable-agent \
  --node-name $FLY_ALLOC_ID \
  --node-ip $(tailscale ip -4) \
  --token $K3S_TOKEN \
  --datastore-endpoint http://pluralkit-sjc-k8s-etcd.internal:2379 \
  --tls-san $(tailscale ip -4) \
  --tls-san sjc-k8s.svc.pluralkit.net \
  --service-cidr 10.21.21.0/24 \
  --cluster-cidr 10.20.0.0/16 \
  --cluster-dns 10.21.21.21 \
  --cluster-domain sjc.k8s.pluralkit.net \
  --disable-helm-controller \
  --disable-network-policy \
  --disable-cloud-controller \
  --disable=traefik \
  --disable=servicelb \
  --disable=metrics-server \
  --disable=local-storage \
  --flannel-backend=none
