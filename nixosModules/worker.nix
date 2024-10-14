{ inputs, pkgs, lib, config, ... }:

{
	# for now, needs 10.0.0.0/16 for db

  # todo: allow for subnets larger than /24
  # todo: also put this in tailscale daemon settings
  options.pkWorkerSubnet = lib.mkOption {
    default = "";
  };

  config = {
    virtualisation.docker.daemon.settings = {
      experimental = true;
      ip6tables = true;
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
      default-address-pools = [{ base = config.pkWorkerSubnet; size = 24; }];
    };

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "nomad"
    ];

    services.nomad = {
      enable = true;
      dropPrivileges = false;
      settings = {
        bind_addr = "${config.pkTailscaleIp}";
        client = {
          enabled = true;
          servers = ["hashi.svc.pluralkit.net"];
          node_class = "compute";
        };
        vault = {
          enabled = true;
          address = "http://active.vault.service.consul:8200";
        };
      };
    };

    systemd.services.consul.serviceConfig.AmbientCapabilities = "cap_net_bind_service";
    services.consul = {
      enable = true;
      extraConfig = {
        data_dir = "/opt/consul";
        bind_addr = "${config.pkTailscaleIp}";
        addresses.dns = "169.254.169.254";
        ports.dns = 53;
        retry_join = ["hashi.svc.pluralkit.net"]; # todo: is this correct for a client?
      };
    };

    services.vector = {
      enable = true;
      settings = {
        sources.docker = {
          type = "docker_logs";
          include_containers = ["gateway-"];
        };
        sinks.opensearch = {
          type = "elasticsearch";
          inputs = ["json"];
          bulk.index = "pluralkit";
          api_version = "v8";
          endpoints = ["http://db.svc.pluralkit.net:9200"];
        };
        transforms.json = {
          type = "remap";
          inputs = ["docker"];
          source = ''
          .data = parse_json(.message) ?? {}
          '';
        };
      };
    };
    systemd.services.vector.serviceConfig.Group = "docker";

    pkServerChecks = [
      { type = "systemd_service_running"; value = "nomad"; }
      { type = "systemd_service_running"; value = "docker"; }
      { type = "systemd_service_running"; value = "vector"; }
    ];
  };
}
