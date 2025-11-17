#!/usr/bin/env bash

export NIX_SSHOPTS="-i ~/.ssh/provisioner"

if [ "$1" == "do_rebuild" ]; then
  user=${user:-root}

  hostname=$3
  action=$2

  exec > >(trap "" INT TERM; sed "s/^/$hostname(stdout): /")
  exec 2> >(trap "" INT TERM; sed "s/^/$hostname(stderr): /" | grep -v 'evaluating file' >&2)

  ip=$(nix eval -v -L ".#nixosConfigurations.$hostname.config.systemd.network.networks.50-vlan10.address" --apply builtins.head | jq -r | sed 's/\// /' | awk '{print $1}')
  echo $hostname at $ip
  if [ "$wait" == "true" ]; then
    echo "tap enter to run build"
    read
  fi
  nixos-rebuild $action --flake .#$hostname --target-host $user@$ip --build-host $user@$ip --use-remote-sudo --show-trace
  exit 0
fi

query=$1
action=$2

export wait=${wait:-false}

hosts=($(find hosts -type f -exec basename {} \; | grep -v default | sed 's/.nix//'))

if [ "$query" == "all" ]; then
  echo "all"
else
  echo "query: $query"
  hosts=($(printf "%s\n" "${hosts[@]}" | grep $query))
fi

if [ "${#hosts[@]}" -eq "0" ]; then
  echo "could not find"
  exit 1
fi

echo "rebuilding ${hosts[@]}"
echo "enter to confirm"
read

if [ "$parallel" == "true" ]; then
  # shut up
  echo 'will cite' | nix run nixpkgs#parallel -- --citation >/dev/null 2>/dev/null
  nix run nixpkgs#parallel -- --ungroup "$0 do_rebuild $action {}" ::: ${hosts[@]}
else
  for hostname in ${hosts[@]}; do
    $0 do_rebuild $action $hostname
  done
fi
