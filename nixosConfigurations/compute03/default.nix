{ inputs, pkgs, lib, ... }:

{
  hardware.cpu.amd.updateMicrocode = true;
  boot.initrd.availableKernelModules = [ "nvme" "ahci" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems = {
    "/" = { device = "/dev/disk/by-label/root"; fsType = "ext4"; };
    "/boot" = { device = "/dev/disk/by-label/boot"; fsType = "vfat"; };
  };

  networking.hostId = "858a0900";
  systemd.network = {
    wait-online.enable = false;
    netdevs."internal" = {
      netdevConfig = { Name = "internal"; Kind = "vlan"; };
      vlanConfig = { Id = 4000; };
    };

    networks."lo" = {
      matchConfig = { Name = "lo"; };
      address = [ "127.0.0.1/8" "[::1]/128" "169.254.169.254" ];
    };

    networks."eth0" = {
      matchConfig = { Name = "eth0"; };
      address = [ "116.202.146.157/26" ];
      gateway = [ "116.202.146.129" ];
      vlan = [ "internal" ];
    };

    networks."internal" = {
      matchConfig = { Name = "internal"; };
      address = [ "10.0.1.7/24" ];
      routes = [
        { routeConfig = { Destination = "10.0.0.0/24"; Gateway = "10.0.1.1"; }; }
      ];
    };
  };

  virtualisation.docker.daemon.settings = {
    experimental = true;
    ip6tables = true;
    ipv6 = true;
    fixed-cidr-v6 = "fd00::/80";
    default-address-pools = [{ base = "172.17.1.0/24"; size = 24; }];
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nomad"
  ];

  services.nomad = {
    enable = true;
    dropPrivileges = false;
    settings = {
      bind_addr = "100.100.251.99";
      client = {
        enabled = true;
        servers = ["100.99.134.112"];
        node_class = "compute";
      };
      vault = {
        enabled = true;
        address = "http://100.99.134.112:8200";
      };
    };
  };

  systemd.services.consul.serviceConfig.AmbientCapabilities = "cap_net_bind_service";
  services.consul = {
    enable = true;
    extraConfig = {
      data_dir = "/opt/consul";
      bind_addr = "100.100.251.99";
      addresses.dns = "169.254.169.254";
      ports.dns = 53;
      retry_join = ["100.99.134.112"];
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
        endpoints = ["http://10.0.1.6:9200"];
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

  networking.nameservers = [ "100.100.100.100" ];

  system.stateVersion = "24.04";
}
