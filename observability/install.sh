#!/bin/sh

set -x

apk fix

rc-update add nftables
service nftables start
sysctl -w

[ "$(grep sdb /etc/fstab >/dev/null; echo $?)" == "1" ] && (
  mkfs.ext4 /dev/sdb
  echo "/dev/sdb /srv auto defaults 0 0" >> /etc/fstab
  mount /srv
)

# todo: just use an apk package
[ ! -d "/usr/local/vicky/bin" ] && (
  mkdir -p /usr/local/vicky/bin

  tmpdir=$(mktemp -d)
  cd $tmpdir

  wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v1.117.1/victoria-metrics-linux-amd64-v1.117.1-cluster.tar.gz
  wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v1.117.1/vmutils-linux-amd64-v1.117.1.tar.gz
  wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v1.22.2-victorialogs/victoria-logs-linux-amd64-v1.22.2-victorialogs.tar.gz

  for file in *; do tar xf $file; done

  chmod +x *

  mv victoria-logs-prod /usr/local/vicky/bin/victorialogs
  mv vmstorage-prod /usr/local/vicky/bin/vmstorage
  mv vminsert-prod /usr/local/vicky/bin/vminsert
  mv vmselect-prod /usr/local/vicky/bin/vmselect
  mv vmalert-prod /usr/local/vicky/bin/vmalert

  cd ~
  rm -rf $tmpdir
)

mkdir -p /srv/logs
mkdir -p /srv/metrics
mkdir -p /srv/alertmanager

function ensure_service {
  svc=$1
  [ "$(rc-update | grep $svc >/dev/null; echo $?)" == "1" ] && (
    rc-update add $svc
    service $svc start
  )
}

# todo: restart services when configuration files updated

ensure_service vlstorage
ensure_service vlproxy

ensure_service vmstorage
ensure_service vminsert
ensure_service vmselect

ensure_service caddy

ensure_service alertmanager
ensure_service vmalert-metrics
ensure_service vmalert-logs
