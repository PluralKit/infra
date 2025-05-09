# Setting up a new server

> This is out of date!

(this document assumes you have basic knowledge of Nix and NixOS configuration)

PluralKit uses Hetzner cloud instances for management (hashistack) and dedicated servers for database/compute. Hetzner doesn't offer NixOS as a boot option, so it has to be installed manually.

For cloud instances: install Debian and use [nixos-infect](https://github.com/elitak/nixos-infect/) through `cloud-init`.

::: warning

  VMs with small RAM (<4G) need a swapfile. Do something like this:

  ```
  fallocate -l 8G /swapfile
  mkswap /swapfile
  swapon /swapfile
  ```
  and add to config:
  ```nix
  swapDevices = [ { device = "/swapfile"; } ];
  ```
:::

For dedicated servers: boot to rescue, install the Nix daemon and run `nix-shell -p nixos-install-tools`. From there, install the same way as from NixOS live install media.

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

### Final steps

Add the new server's public and VPN (Tailscale) IPs to DNS in `dns/dnsconfig.js`.

Add the server to the server-checks worker script in `packages/server-checks/worker.ts`.

## Management server

Copy `/etc/pluralkit/nomad-vault-token.hcl` from an existing management server.

Add `nixosModules/hashi.nix` to imports in the new server's configuration and rebuild.

```sh
$ vault operator raft join http://hashi.svc.pluralkit.net:8200
$ vault operator unseal

$ nomad server join hashi.svc.pluralkit.net
```

Try not to break the Raft clusters, they're picky (consul should automatically join the raft cluster)

Add the server to `hashi.svc.pluralkit.net` DNS.

## Compute server

Add `nixosModules/worker.nix` to imports in the new server's configuration and rebuild.

Choose an unused subnet for container IPs (172.17.xxx.0/24).
\nSet it as `pkWorkerSubnet` in the config, and add a tailscale route for it: `tailscale set --advertise-routes <subnet>`.
\nApprove the route in the Tailscale dashboard.

Set the server to eligible in Nomad, and you're done.

## Edge server

Assign an IPv6 subnet from Vultr instance -> Settings -> IPv6.

Copy the configuration from an existing edge server (replace the IPs, set `pkTailscaleIp` to empty, comment out `edge.nix`).

Copy `/etc/pluralkit` from an existing edge server.

## Database/other

There are likely manual or otherwise unknown steps here, please check with alyssa in #internal-stuffs.
