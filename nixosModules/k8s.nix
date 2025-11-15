{ pkgs, lib, config, ... }:

with lib;
let
  cfg = config.services.pk-k3s;

  bridge6Subnet = let
    pt1 = builtins.substring 0 4 config.networking.hostId;
    pt2 = builtins.substring 4 8 config.networking.hostId;
  in "fdef:${pt1}:${pt2}::/80";

  containerdConfig = pkgs.writeText "config-v3.toml.tmpl" ''
    {{ template "base" . }}

    [plugins.'io.containerd.cri.v1.runtime'.cni]
      bin_dir = '/var/lib/rancher/k3s/data/cni'
  '';
in
{
  options.services.pk-k3s = {
    bridgeSubnet = mkOption {
      type = types.str;
    };
  };

  config = {
    environment.etc."cni/net.d/10-bridge.conflist".text = ''
      {
        "name":"cbr0",
        "cniVersion":"1.0.0",
        "plugins":[
          {
              "name": "mynet",
              "type": "bridge",
              "bridge": "br0",
              "isDefaultGateway": true,
              "forceAddress": false,
              "ipMasq": true,
              "hairpinMode": false,
              "ipam": {
                  "type": "host-local",
                  "ranges": [
                    [{
                      "subnet": "${cfg.bridgeSubnet}"
                    }],
                    [{
                      "subnet": "${bridge6Subnet}"
                    }]
                  ]
              }
          }
        ]
      }
    '';

    systemd.tmpfiles.rules = [
      "L /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl - - - - ${containerdConfig}"
    ];

    systemd.services.k3s = {
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscale-ready.service" ];
      wants  = [ "tailscale-ready.service" ];
      serviceConfig.ExecStart = pkgs.writeShellScript "k3s" ''
        ${pkgs.k3s}/bin/k3s agent \
          --server https://sjc-k8s.svc.pluralkit.net:6443 \
          --token $(cat /etc/pluralkit/k3s-token) \
          --debug \
          --node-name $(cat /etc/hostname) \
          --node-ip $(${pkgs.tailscale}/bin/tailscale ip -4)
          --flannel-backend=none
    '';
    };

    pkServerChecks = [
		  { type = "systemd_service_running"; value = "k3s"; }
    ];
  };
}
