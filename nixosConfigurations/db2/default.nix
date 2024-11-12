{ inputs
, pkgs
, lib
, config
, ...
}:

{
  imports = [
    ./hw.nix
    ./redis.nix
    ./postgres.nix
    ./metrics.nix
    ../../nixosModules/worker.nix
  ];

  pkTailscaleIp = "100.83.67.99";
  pkWorkerSubnet = "172.17.2.0/24";

  networking.firewall.trustedInterfaces = [ "docker0" "fly" ];

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
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.seq-logs = {
      image = "datalust/seq";
      ports = [
        "${config.pkTailscaleIp}:8010:80"
        "[fdaa:9:e856:a7b:16a9:0:a:2]:8010:80"
        "${config.pkTailscaleIp}:5341:5341"
        "[fdaa:9:e856:a7b:16a9:0:a:2]:5341:5341"
      ];
      volumes = [ "/srv/data1/seq-logs:/data" ];
      environment.ACCEPT_EULA = "y";
      environment.SEQ_API_LISTENURIS = "http://[::]:80,http://[::]:5341";
    };
    containers.opensearch-dashboards = {
      image = "opensearchproject/opensearch-dashboards:2.11.1";
      ports = [ "${config.pkTailscaleIp}:5601:5601" ];
      environment.OPENSEARCH_HOSTS = "[\"http://db.svc.pluralkit.net:9200\"]";
      environment.DISABLE_SECURITY_DASHBOARDS_PLUGIN = "true";
    };
  };

  networking.firewall.interfaces."internal".allowedTCPPorts = [ 9000 9200 ];

  services.opensearch = {
    enable = true;
    settings."network.host" = "${config.pkTailscaleIp}";
    dataDir = "/srv/data2/elasticsearch";
    extraJavaOptions = [ "-Xmx32g"   "-Djava.net.preferIPv4Stack=true" ];
  };

  networking.wireguard.interfaces.fly = {
    privateKeyFile = "/opt/fly-wireguard-key";
    peers = [{
      publicKey = "yUyg63j5+17YeJ7gRhxoQuF6rvdX0JF59M6skytJFTQ=";
      endpoint = "ams1.gateway.6pn.dev:51820";
      allowedIPs = ["fdaa:9:e856::/48"];
      persistentKeepalive = 15;
    }];
    ips = ["fdaa:9:e856:a7b:16a9:0:a:2/120"];
  };

  networking.firewall.interfaces.fly.allowedTCPPorts = [ 5432 5434 6379 5341 8086 ];

  system.stateVersion = "23.11";
}
