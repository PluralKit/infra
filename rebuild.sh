#!/usr/bin/env bash

hostname=$1
user=alyssa

ip=$(nix eval -v -L ".#nixosConfigurations.$hostname.config.systemd.network.networks.eth0.address" | jq -r .[0] | sed 's/\/26//')

echo $hostname at $ip

nixos-rebuild $2 --flake .#$hostname --target-host $user@$ip --build-host $user@$ip --use-remote-sudo
