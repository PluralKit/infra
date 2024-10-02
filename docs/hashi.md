# HashiStack

"HashiStack" refers to a set of Hashicorp software used together to manage infrastructure. PluralKit uses **Nomad** (container orchestration), **Consul** (service discovery) and **Vault** (secrets management). Usually, HashiStack also includes Terraform, but we don't use that.

For lack of a better place to put it, our Hashistack nodes also include [Nirn Discord ratelimit proxy](https://github.com/germanoeich/nirn-proxy).

Below are some notes on operating Hashistack. todo: add more things

## Raft consensus

Nomad/Consul/Vault store data across hosts with [Raft](https://raft.github.io/). This requires a "**majority**" (count/2 + 1) of servers to be live before the service is accessible. (this implies it's impossible to scale down to 1 instance without peers.json recovery)

## Decommissioning

First of all, make sure there are **at least 2** other live hashistack nodes.

- remove the DNS entry for `hashi.svc.pluralkit.net`

- stop `nirn-proxy`: `systemctl stop nirn-proxy`

- remove the nomad server:
```sh
$ systemctl stop nomad

# (from a different server) 
$ nomad operator raft remove-peer <node-id>
```

- remove the vault server:
```sh
$ vault operator step-down
$ vault operator raft remove-peer <node-id>
$ systemctl stop vault
```

- remove the consul server: `systemctl stop consul`

Delete the instance on Hetzner dashboard.

It will take some time for the server to disappear from `nomad server members` / `consul members`, this is normal and doesn't cause any issues.

## misc

- vault CLI needs a token in environment for every operation, otherwise will 403 (unlike nomad/consul)
