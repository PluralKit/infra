#!/bin/false
exit 1
# don't run this script, instead read through it and understand what it does

CLUSTER_COUNT=53 # id of largest cluster, 0-indexed

# launch nirn-proxy
#for unused in 1 2 3; do
#  fly vol create -a pluralkit-nirn-proxy -r ams placement -y
#  fly m run -a pluralkit-nirn-proxy -r ams -v placement:/unused \
#    --vm-size shared-cpu-2x \
#    -e PORT=8002 -e BIND_IP=fly-local-6pn -e CLUSTER_DNS=pluralkit-nirn-proxy.internal \
#    registry.fly.io/pluralkit-nirn-proxy:2024110800
#done

curl -H "Authorization: Bearer $(fly auth token)" https://api.machines.dev/v1/apps/pluralkit-nirn-proxy/machines \
  --json '{
"region": "ams",
"config": {
  "env": {
    "BIND_IP": "fly-local-6pn",
    "CLUSTER_DNS": "pluralkit-nirn-proxy.internal",
    "PORT": "8002",
    "METRICS_BIND": "0.0.0.0:9002"
  },
  "guest": {
    "cpu_kind": "shared",
    "cpus": 2,
    "memory_mb": 512
  },
  "image": "registry.fly.io/pluralkit-nirn-proxy:2024110801",
  "restart": {
    "policy": "on-failure",
    "max_retries": 10
  },
  "metrics": {
    "path": "/metrics",
    "port": 9002,
    "https": false
  }
}}'

# launch gateway
fly secrets set -a pluralkit-gateway \
  pluralkit__discord__bot_token=secret

fly m list -a pluralkit-gateway > /tmp/data
for idx in $(seq 2 $CLUSTER_COUNT); do
  curl \
    -H "Authorization: Bearer $(fly auth token)" \
    https://api.machines.dev/v1/apps/pluralkit-gateway/machines/$(grep "cluster$idx " /tmp/data | awk '{print $1}') \
    --json '{"config": {
            "env": {
                "RUST_LOG": "info",
                "pluralkit__api__ratelimit_redis_addr": "1",
                "pluralkit__api__remote_url": "1",
                "pluralkit__api__temp_token2": "1",
                "pluralkit__db__data_db_uri": "1",
                "pluralkit__db__data_redis_addr": "redis://6pndb.svc.pluralkit.net:6379",
                "pluralkit__discord__api_base_url": "http://pluralkit-nirn-proxy.internal:8002/api/v10",
                "pluralkit__discord__cache_api_addr": "[::]:5000",
                "pluralkit__discord__client_id": "466378653216014359",
                "pluralkit__discord__client_secret": "1",
                "pluralkit__discord__cluster__node_id": "'"$idx"'",
                "pluralkit__discord__cluster__total_nodes": "54",
                "pluralkit__discord__cluster__total_shards": "864",
                "pluralkit__discord__max_concurrency": "16",
                "pluralkit__json_log": "true",
                "pluralkit__run_metrics_server": "true"
            },
            "init": {},
            "guest": {
                "cpu_kind": "shared",
                "cpus": 8,
                "memory_mb": 2048
            },
            "metadata": {
                "fly_process_group": "cluster'"$idx"'"
            },
            "image": "ghcr.io/pluralkit/gateway:1c9b7fae99102029817b7d307f7380675fece6b0",
            "metrics": {
              "path": "/metrics",
              "port": 9000,
              "https": false
            }
        }}' -v
done

# launch avatars
fly secrets set -a pluralkit-avatars \
  pluralkit__db__db_password=secret \
  pluralkit__avatars__s3__application_key=secret

for unused in 1 2 3; do
  fly vol create -a pluralkit-avatars -r ams placement -y
  fly m run -a pluralkit-avatars \
    -r ams -v placement:/unused \
    -e RUST_LOG=info -e pluralkit__json_log=true \
                                                 \
		-e pluralkit__db__data_db_uri="postgresql://pluralkit@6pndb.svc.pluralkit.net:5432/pluralkit" \
		-e pluralkit__avatars__cdn_url="https://cdn.pluralkit.me/" \
		-e pluralkit__avatars__s3__bucket="pluralkit-avatars" \
		-e pluralkit__avatars__s3__endpoint="https://s3.eu-central-003.backblazeb2.com" \
		-e pluralkit__avatars__s3__application_id="0031de9bd0a26160000000005" \
                                                \
		-e pluralkit__db__data_redis_addr=1         \
                                                \
    ghcr.io/pluralkit/avatars:0e75e887a5f15e13552dad286303c05d79999292
done

# launch bot
fly secrets set -a pluralkit-dotnet-bot \
  PluralKit__Bot__Token=secret \
  PluralKit__DatabasePassword=secret \
  PluraKit__SentryUrl=secret \
  PluralKit__DispatchProxyToken=secret

for idx in $(seq 1 $CLUSTER_COUNT); do
  fly m run -a pluralkit-dotnet-bot \
    -r ams \
    --vm-size shared-cpu-8x \
    -e PluralKit__Bot__ClientId=466378653216014359 \
    -e PluralKit__Bot__AdminRole=913986523500777482 \
    -e PluralKit__Bot__DiscordBaseUrl=http://pluralkit-nirn-proxy.internal:8002/api/v10 \
    -e PluralKit__Bot__HttpCacheUrl=http://process.pluralkit-gateway.internal:5000 \
    -e PluralKit__Bot__HttpUseInnerCache=true \
    -e PluralKit__Bot__AvatarServiceUrl=http://pluralkit-avatars.internal:5000 \
                                              \
    -e PluralKit__Bot__MaxShardConcurrency=16 \
    -e PluralKit__Bot__UseRedisRatelimiter=true \
                                               \
    -e PluralKit__Bot__Cluster__TotalShards=864 \
    -e PluralKit__Bot__Cluster__TotalNodes=54 \
    -e PluralKit__Bot__Cluster__NodeName=pluralkit-$idx \
                                                \
    -e  PluralKit__Database="Host=6pndb.svc.pluralkit.net;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=25;Minimum Pool Size = 25;Max Auto Prepare=25" \
    -e  PluralKit__MessagesDatabase="Host=6pndb.svc.pluralkit.net;Port=5434;Username=pluralkit;Database=messages;Maximum Pool Size=25;Minimum Pool Size = 25;Max Auto Prepare=25" \
    -e  PluralKit__RedisAddr=6pndb.svc.pluralkit.net:6379,abortConnect=false \
    -e  PluralKit__InfluxUrl=http://6pndb.svc.pluralkit.net:8086 \
    -e  PluralKit__InfluxDb=pluralkit \
    -e  PluralKit__SeqLogUrl=http://6pndb.svc.pluralkit.net:5341 \
    -e  PluralKit__DispatchProxyUrl=http://dispatch.svc.pluralkit.net \
                                             \
    -e  PluralKit__ConsoleLogLevel=2 \
    -e  PluralKit__ElasticLogLevel=1 \
                                             \
    -e  PluralKit__FileLogLevel=5 \
    ghcr.io/pluralkit/pluralkit:asdfasdfasdf
done
