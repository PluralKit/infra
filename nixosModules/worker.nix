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

    systemd.services.vector = let
      make_rs_svc_config = name: ''
        [sources.docker-rust-${name}]
        type = "docker_logs"
        include_containers = ["${name}-"]

        [transforms.tf-docker-rust-${name}]
        type = "remap"
        inputs = ["docker-rust-${name}"]
        source = ".data = parse_json(.message) ?? {}"

        [sinks.opensearch-docker-rust-${name}]
        type = "elasticsearch"
        api_version = "v8"
        inputs = ["tf-docker-rust-${name}"]
        bulk.index = "pluralkit-${name}"
        endpoints = ["http://db.svc.pluralkit.net:9200"]
      '';
      serviceConfig = ''
        ${make_rs_svc_config "api"}
        ${make_rs_svc_config "avatars"}
        ${make_rs_svc_config "avatar_cleanup"}
        ${make_rs_svc_config "gateway"}
      '';
    in {
      description = "Vector.dev (logs)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.vector}/bin/vector --config ${pkgs.writeTextFile {
          name = "vector.conf";
          text = serviceConfig;
        }}";
        DynamicUser = true;
        Group = "docker";
        Restart = "always";
        StateDirectory = "vector";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };
      unitConfig = {
        StartLimitIntervalSec = 10;
        StartLimitBurst = 5;
      };
    };

    pkServerChecks = [
      { type = "systemd_service_running"; value = "nomad"; }
      { type = "systemd_service_running"; value = "docker"; }
      { type = "systemd_service_running"; value = "vector"; }
    ];
  };
}
