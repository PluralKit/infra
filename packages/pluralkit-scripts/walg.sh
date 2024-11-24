#!/bin/sh

. /etc/pluralkit/walg-secrets

export WALG_S3_PREFIX=s3://pluralkit-backups/$1/
export PGHOST=/var/run/postgresql
export PGUSER=postgres
export PGPORT=$2
export PGDATABASE=$3

shift
shift
shift

# todo: use a binary from packages
/opt/wal-g-bin $@
