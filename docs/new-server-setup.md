# Setting up a new server

(this document assumes you have basic knowledge of Nix and NixOS configuration)

PluralKit uses Hetzner cloud instances for management (hashistack, nirn-proxy) and dedicated servers for database/compute. Hetzner doesn't offer NixOS as a boot option, so it has to be installed manually.

For cloud instances: install Debian and use [nixos-infect](https://github.com/elitak/nixos-infect/).

For dedicated servers: boot to rescue, install the Nix daemon and run `nix-env -iA nixos-install-tools`. From there, install the same way as from NixOS live install media.

Now you have a blank NixOS server, ready for configuration to be applied.
- Create a new directory under `nixosConfigurations`, and add a `default.nix` file with the base machine configuration (hardware, IPs, generate hostId, stateVersion).
- `git add nixosConfigurations/newhostname/` for nix to pick it up
- Add the new server to `nixosConfigurations/default.nix`
- Rebuild the server with the new configuration
  - this needs to be done as root, but after that root login will be unavailable as users are set up
- Log in with your username, and **eboot** to make sure the server comes up cleanly
- Log in to Tailscale: `sudo tailscale up`
- Add the new server to the `prod` tag in the Tailscale admin dashboard
- Add the server's new Tailscale IP to `pkTailscaleIp` configuration key, and reubild.

Continue to one of the machine-type-specific sections below.

### Note about DNS

Remember to add the new server's public and VPN (Tailscale) IPs to DNS in `dns/dnsconfig.js`.

## Management server

Copy `/opt/nomad-vault-token.hcl` from an existing management server.

```sh
$ sudo mkdir /opt/consul
$ sudo chown -R consul /opt/consul`
```

Add `nixosModules/hashi.nix` to imports in the new server's configuration and rebuild.

```sh
$ vault operator raft join http://hashi.svc.pluralkit.net:8200
$ vault operator unseal

$ nomad server join hashi.svc.pluralkit.net
```

Try not to break the Raft clusters, they're picky (consul/vault should automatically join their raft clusters)

Add the server to `hashi.svc.pluralkit.net` DNS.

## Compute server

todo: abstract out compute server stuff

Add `nixosModules/compute.nix` to imports in the new server's configuration and rebuild.

Choose an unused subnet for container IPs (172.17.xxx.0/24).

Set the server to eligible in Nomad, and you're done.

When decommissioning the old compute server, **remember to move Sentry manually** as it's not managed through NixOS. Data is stored in `/opt/sentry` and `/opt/sentry-data`.

## Database/other

There are likely manual or otherwise unknown steps here, please check with alyssa in #internal-stuffs.
