#!/bin/sh

sysctl vm.max_map_count=1048576
sysctl fs.file-max=65536
ulimit -n 65535
ulimit -l unlimited
chown -R opensearch /usr/share/opensearch/data
exec su -p opensearch ./opensearch-docker-entrypoint.sh
