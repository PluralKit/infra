#!/bin/false

# Example script to set up a production environment for PluralKit

## Run the following on a "master" server (example IP: 10.0.0.2)
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt update && apt install -y nomad

export NOMAD_ADDR=http://10.0.0.2:4646
export VAULT_ADDR=http://10.0.0.2:8200

curl https://get.docker.com | sh

cat <<EOF
data_dir = "/opt/nomad/data"
bind_addr = "10.0.0.2"

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = false
}
EOF > /etc/nomad.d/nomad.hcl

# set up Vault
apt update && apt install -y vault
cat <<EOF
ui = true

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address = "10.0.0.2:8200"
  tls_disable = 1
}
EOF > /etc/vault.d/vault.hcl

vault operator init -key-shares=1 -key-threshold=1 # save secrets from this command
vault operator unseal
vault login

vault secrets enable kv
vault kv put kv/pluralkit discordToken=tokenhere databasePassword=passwordhere sentryUrl=https://secreturlhere@sentry.pluralkit.me/1

echo 'path "kv/pluralkit" { capabilities = ["list", "read"] }' > policy.hcl
vault policy write read-kv policy.hcl

cat <<EOF

vault {
  enabled = true
  address = "http://10.0.0.2:8200"
  token = "<nomad server root token>"
}
EOF >> /etc/nomad.d/nomad.hcl

## Run the following on a "database" server (example IP: 10.0.0.3)
docker run -d --name postgres \
    -p 10.0.0.3:5432:5432 \
    -v /mnt/postgresql:/var/lib/postgresql/data \
    --shm-size=1g \
    postgres:13-alpine

docker run -d --name influxdb \
    -p 10.0.0.3:8086:8086 \
    -v /mnt/influxdb:/var/lib/influxdb \
    influxdb:1.8

docker run -d --name redis \
    -p 10.0.0.3:6379:6379 \
    eqalpha/keydb

## Use the cloud-init configuration in `cloud-init.yml` to deploy a few Nomad clients

## Run the following on a laptop, forwarding port 4646 to localhost for Nomad configuration

nomad job run pluralkit.hcl