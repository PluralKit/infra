# PluralKit NixOS infrastructure

## Quick command list

* Updating configs on an existing machine: `nixos-rebuild switch --flake .#`

## System configuration

Each system gets a directory in `nixosConfigurations`. `default.nix` in
each directory is the equivalent of `/etc/nixos/configuration.nix`,
and `hw.nix` is the equivalent of `/etc/nixos/hardware-configuration.nix`.

The host list at the bottom of `nixosConfigurations/default.nix` needs to
be updated when adding new systems.

Each system configuration automatically has `nixosModules/base/` imported -
any "global" configuration that *all* of our infrastructure should have
belongs in there.

## User configuration

Admin user definitions are in `nixosModules/base/users.nix` as `userList`.
SSH keys for each user are stored in `sshKeys/<USERNAME>` - all admin user
SSH keys also get added to the root account, and `sudo` is passwordless.

Please keep UIDs sequentially listed!
