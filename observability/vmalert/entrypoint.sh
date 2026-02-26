#!/bin/sh

am_ips=$(nslookup pluralkit-alertmanager.internal | grep fdaa:9:e856 | awk '{print $2}')

am=""
for ip in $am_ips; do am="$am -notifier.url=http://[$ip]:9093"; done

set -- \
    $am \
    -enableTCP6 \
    -remoteWrite.url=https://insert.fly-metrics.net/ \
    -remoteRead.url=https://api.fly.io/prometheus/pluralkit-50/ \
    -remoteWrite.basicAuth.username=fly-804566 \
    -datasource.headers="Authorization:$QUERY_TOKEN" \
    -remoteWrite.basicAuth.password=$INGEST_TOKEN \
    -remoteRead.headers="Authorization:$QUERY_TOKEN" \
    -secret.flags=datasource.headers,remoteRead.headers,remoteWrite.headers,notifier.headers

if [ "$FLY_APP_NAME" = "pluralkit-vmalert-logs" ]; then
    set -- "$@" \
        -rule=/vmalert-logs.yml \
        -datasource.url=https://api.fly.io/victorialogs/pluralkit-50/ \
        -rule.defaultRuleType=vlogs
else
    set -- "$@" \
        -rule=/vmalert-metrics.yml \
        -datasource.url=https://api.fly.io/prometheus/pluralkit-50/
fi

exec /vmalert-prod "$@"
