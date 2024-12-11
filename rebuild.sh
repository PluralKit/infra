#!/usr/bin/env bash

query=$1
user=${user:-alyssa}
wait=${wait:-false}

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

for hostname in ${hosts[@]}; do
  ip=$(nix eval -v -L ".#nixosConfigurations.$hostname.config.systemd.network.networks.eth0.address" | jq -r .[0] | sed 's/\// /' | awk '{print $1}')
  echo $hostname at $ip
  if [ "$wait" == "true" ]; then
    echo "tap enter to run build"
    read
  fi
  nixos-rebuild $2 --flake .#$hostname --target-host $user@$ip --build-host $user@$ip --use-remote-sudo
done

