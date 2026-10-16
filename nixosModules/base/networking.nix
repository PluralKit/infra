{ pkgs
, config
, lib
, inputs
, pkgs-unstable
, ...
}:
let 
  cfg_bond = config.pluralkit.bond-setup;

  vlan = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.int;
      };
      addresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      gateway4 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      gateway6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      mtu = lib.mkOption {
        type = lib.types.str;
        default = "1500";
      };
      metric = lib.mkOption {
        type = lib.types.int;
      };
      bridge = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };
in
{
  options.pluralkit.bond-setup = {
    enable = lib.mkEnableOption "quanta node bond setup";
    bondAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    bondGateway = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    vlans = lib.mkOption {
      type = lib.types.attrsOf vlan;
      default = {};
    };
  };

  config = lib.mkMerge [
    {
      networking.useDHCP = false;
      networking.usePredictableInterfaceNames = false;
      systemd.network.enable = true;

      networking.firewall = {
        trustedInterfaces = [ "tailscale0" ];
        checkReversePath = "loose";
      };

      services.resolved = {
        enable = true;
        llmnr = "resolve";
        fallbackDns = [ "1.1.1.1" "1.0.0.1" ];
      };

      systemd.network = {
        wait-online.enable = false;
        networks."lo" = {
          matchConfig = { Name = "lo"; };
          address = [ "127.0.0.1/8" "[::1]/128" "169.254.254.169" ];
        };
      };

      services.tailscale = {
        enable = true;
        package = pkgs-unstable.tailscale;
        extraSetFlags = [ "--accept-routes" ];
      };
    }
    (lib.mkIf cfg_bond.enable {
      networking.firewall.trustedInterfaces = [ "bond0" ];
      systemd.network = {
        netdevs = {
          "10-bond0" = {
            netdevConfig = {
              Kind = "bond";
              Name = "bond0";
            };
            bondConfig = {
              Mode = "active-backup";
              MIIMonitorSec = "100ms"; 
              PrimaryReselectPolicy = "always";
            };
          };
        } // lib.mapAttrs' (name: vcfg: lib.nameValuePair "20-vlan${toString vcfg.id}" {
          netdevConfig = {
            Kind = "vlan";
            Name = "vlan${toString vcfg.id}";
          };
          vlanConfig.Id = vcfg.id;
        }) cfg_bond.vlans;

        networks = {
          "30-eth0" = {
            matchConfig.Name = "eth0";
            networkConfig.Bond = "bond0";
            linkConfig.MTUBytes = "9000";
          };
          "30-eth1" = {
            matchConfig.Name = "eth1";
            networkConfig.Bond = "bond0";
            linkConfig.MTUBytes = "9000";
          };
          "40-bond0" = {
            matchConfig.Name = "bond0";
            vlan = lib.mapAttrsToList (name: vcfg: "vlan${toString vcfg.id}") cfg_bond.vlans;

            address = cfg_bond.bondAddresses;
            routes = lib.optional (cfg_bond.bondGateway != null) {
              Gateway = cfg_bond.bondGateway;
              Metric = 200;
            };

            networkConfig.LinkLocalAddressing = "no";
            linkConfig = {
              RequiredForOnline = "carrier";
              MTUBytes = "9000";
            };
          };
        } // lib.mapAttrs' (name: vcfg: lib.nameValuePair "50-vlan${toString vcfg.id}" {
          matchConfig.Name = "vlan${toString vcfg.id}";
          networkConfig.Bridge = lib.mkIf (vcfg.bridge != null) vcfg.bridge;
          address = vcfg.addresses;
          routes = (lib.optional (vcfg.gateway4 != null) {
            Gateway = vcfg.gateway4;
            Metric = vcfg.metric;
          }) ++ (lib.optional (vcfg.gateway6 != null) {
            Gateway = vcfg.gateway6;
            Metric = vcfg.metric;
          });
          linkConfig.MTUBytes = vcfg.mtu;
        }) cfg_bond.vlans;
      };

      systemd.services.ethtool-bond = {
        description = "ethtool-bond";

        bindsTo = [ "sys-subsystem-net-devices-bond0.device" ];
        after = [ "sys-subsystem-net-devices-bond0.device" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          User = "root";
          RemainAfterExit = true;
        };

        script = ''
          INTERFACES="bond0 eth0 eth1"
          for INT in $INTERFACES; do
              ${pkgs.ethtool}/bin/ethtool -K $INT rx on tx on gso on gro on rx-udp-gro-forwarding on rx-gro-list off 
          done
        '';
      };

      boot.kernel.sysctl = {
        "net.core.rmem_max" = 8388608;
        "net.core.wmem_max" = 8388608;
      };
    })

    # temp(?) debugging stuff
    {
      services.netdata = {
        enable = true;
        config.web."bind to" = config.pkTailscaleIp;
        configDir."go.d/ping.conf" = pkgs.writeText "ping.conf" ''
          jobs:
          - name: utils-hcash1-05a12be2_public
            hosts: [ "5.161.43.226" ]
            update_every: 1
          - name: utils-hcash1-05a12be2_tailscale
            hosts: [ "100.79.33.60" ]
            update_every: 1

          - name: database-node1-bd9aa148_public
            hosts: [ "91.208.228.69" ]
            update_every: 1
          - name: database-node1-bd9aa148_tailscale
            hosts: [ "100.123.150.13" ]
            update_every: 1

          - name: worker-node2-d13866af_public
            hosts: [ "91.208.228.70" ]
            update_every: 1
          - name: worker-node2-d13866af_tailscale
            hosts: [ "100.93.93.55" ]
            update_every: 1

          - name: worker-node3-6f0ac4c4_public
            hosts: [ "91.208.228.71" ]
            update_every: 1
          - name: worker-node3-6f0ac4c4_tailscale
            hosts: [ "100.68.206.85" ]
            update_every: 1

          - name: worker-node4-f57b21c7_public
            hosts: [ "91.208.228.72" ]
            update_every: 1
          - name: worker-node4-f57b21c7_tailscale
            hosts: [ "100.68.216.79" ]
            update_every: 1
        '';
      };

      services.vmagent.prometheusConfig.scrape_configs = [{
        job_name = "netdata";
        static_configs = [{
          targets = ["http://${config.networking.hostName}.vpn.pluralkit.net:19999/api/v1/allmetrics?format=prometheus"];
        }];
      }];

      systemd.services.netdata = {
        serviceConfig = {
          CapabilityBoundingSet = [ "CAP_NET_RAW" ];
          AmbientCapabilities = [ "CAP_NET_RAW" ];
        };
      };
    }
  ];
    

  
}
