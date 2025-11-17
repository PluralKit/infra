#!/usr/bin/env bash

query=$1
shift
user=${user:-root}
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

echo "executing $@ on ${hosts[@]}"
echo "enter to confirm"
read

for hostname in ${hosts[@]}; do
  ip=$(nix eval -v -L ".#nixosConfigurations.$hostname.config.systemd.network.networks.50-vlan10.address" --apply builtins.head | jq -r | sed 's/\// /' | awk '{print $1}')
  echo $hostname at $ip
  if [ "$wait" == "true" ]; then
    echo "tap enter to run command"
    read
  fi
  ssh -t -i ~/.ssh/provisioner $user@$ip $@
done
