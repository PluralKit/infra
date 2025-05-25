#!/bin/sh

export ALERTMANAGER_WEBHOOK_URL=$(op item get evl2ls4xh7amq4p55vtnjf65oy --format=json | jq -r '.fields[] | select(.label == "credential") | .value')
nix run nixpkgs#envsubst -- -i etc/alertmanager/alertmanager.yml.template -o etc/alertmanager/alertmanager.yml

# keep forgetting this
chmod +x etc/init.d/*

for h in 1 2 3; do
  host=o11y-$h.prod.pluralkit.net

  rsync -avP . $host:/
  ssh -t $host sh /install.sh
done
