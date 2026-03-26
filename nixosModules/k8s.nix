{ pkgs, pkgs-unstable, lib, config, ... }:

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
              "ipMasq": false,
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

    networking.nftables = {
      enable = true;
      tables = {
        "masquerade4" = {
          family = "ip";
          content = ''
            chain postrouting {
              type nat hook postrouting priority srcnat; policy accept;
              ip saddr ${cfg.bridgeSubnet} ip daddr != 10.20.0.0/15 counter masquerade
            }
          '';
        };
        "masquerade6" = {
          family = "ip6";
          content = ''
            chain postrouting {
              type nat hook postrouting priority 100; policy accept;
              ip6 saddr fdef::/16 ip6 daddr != ${bridge6Subnet} masquerade
            }
          '';
        };
      };
    };

    networking.firewall.checkReversePath = "loose";

    networking.firewall.trustedInterfaces = [ "br0" ];
    networking.firewall.extraForwardRules = ''
      iifname "br0" ip daddr 10.20.0.0/15 accept
      oifname "br0" ip saddr 10.20.0.0/15 accept
    '';

    boot.kernelModules = [ "br_netfilter" ];
    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
    };

    systemd.services.k3s = {
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscale-ready.service" ];
      wants  = [ "tailscale-ready.service" ];
      serviceConfig.ExecStart = pkgs.writeShellScript "k3s" ''
        ${pkgs-unstable.k3s_1_35}/bin/k3s agent \
          --server https://sjc-k8s.svc.pluralkit.net:6443 \
          --token $(cat /etc/pluralkit/k3s-token) \
          --debug \
          --node-name $(cat /etc/hostname) \
          --node-ip $(${pkgs.tailscale}/bin/tailscale ip -4)
          --flannel-backend=none
    '';
    };

    systemd.network = {
      netdevs = {
        "15-br0" = {
          netdevConfig = {
            Kind = "bridge";
            Name = "br0";
          };
        };
      };
      networks = {
        "45-br0" = {
          matchConfig.Name = "br0";
          linkConfig.ActivationPolicy = "up";
          networkConfig = {
            LinkLocalAddressing = "no";
            IPv4ProxyARP = true;
          };

          routes = [
            {
              Destination = "10.20.0.0/15";
              Scope = "link";
            }
            {
              Destination = "fdef::/16";
              Scope = "link";
            }
          ];
        };
      };
    };

    pkServerChecks = [
		  { type = "systemd_service_running"; value = "k3s"; }
    ];
  };
}
