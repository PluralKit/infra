{ inputs
, pkgs
, lib
, ...
}:

{
  imports = [
    ./hw.nix
    ./redis.nix
    ./postgres.nix
    ./metrics.nix
  ];

  boot.kernel.sysctl = {
    "net.ipv4.tcp_max_syn_backlog" = 8192;
    "net.core.somaxconn" = 8192;
  };

  networking.hostId = "09a9f4ac";
  systemd.network = {
    netdevs."internal" = {
      netdevConfig = { Name = "internal"; Kind = "vlan"; };
      vlanConfig = { Id = 4000; };
    };

    networks."eth0" = {
      matchConfig = { Name = "eth0"; };
      address = [ "148.251.178.57/26" ];
      gateway = [ "148.251.178.1" ];
      vlan = [ "internal" ];
    };

    networks."internal" = {
      matchConfig = { Name = "internal"; };
      address = [ "10.0.1.6/24" ];
      routes = [
        { routeConfig = { Destination = "10.0.0.0/24"; Gateway = "10.0.1.1"; }; }
      ];
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.seq-logs = {
      image = "datalust/seq";
      ports = [
        "10.0.1.6:8010:80"
        "10.0.1.6:5341:5341"
      ];
      volumes = [ "/srv/data1/seq-logs:/data" ];
      environment.ACCEPT_EULA = "y";
    };
  };

  system.stateVersion = "23.11";
}
