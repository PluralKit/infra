{ config, inputs, pkgs, lib, modulesPath, ... }:

let
  hostname = config.networking.hostName;
  pkTailscaleIp = config.pkTailscaleIp;
in {
  # for hashistack (nomad/consul/vault, + nirn-proxy) servers

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nomad" "vault-bin"
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "vault-bin-1.15.6"
  ];

  # always talk to local host on hashi servers
  environment.variables = {
    NOMAD_ADDR = lib.mkForce "http://${pkTailscaleIp}:4646";
    CONSUL_HTTP_ADDR = lib.mkForce "http://${pkTailscaleIp}:8500";
    VAULT_ADDR = lib.mkForce "http://${pkTailscaleIp}:8200";
  };

  services.nomad = {
    enable = true;
    dropPrivileges = true; # client needs to be root, server doesn't
    enableDocker = false;
    settings = {
      bind_addr = "${pkTailscaleIp}";
      server.enabled = true;
      consul.address = "http://${pkTailscaleIp}:8500";
      vault = {
        enabled = true;
        address = "http://active.vault.service.consul:8200";
      };
    };
    extraSettingsPaths = [ "/opt/nomad-vault-token.hcl" ];
  };

  systemd.services.consul.serviceConfig = {
    AmbientCapabilities = "cap_net_bind_service";
    ReadWritePaths = "/opt/consul";
  };
  services.consul = {
    enable = true;
    extraConfig = {
      ui_config.enabled = true;
      server = true;
      data_dir = "/opt/consul";
      bind_addr = "${pkTailscaleIp}";
      addresses.http = "${pkTailscaleIp}";
      addresses.dns = "169.254.169.254";
      ports.dns = 53;
      retry_join = [ "hashi.svc.pluralkit.net" ];
    };
  };

  services.vault = {
    enable = true;
    package = pkgs.vault-bin;
    address = "${pkTailscaleIp}:8200";
    storagePath = "/opt/vault";
    storageBackend = "raft";
    extraConfig = ''
      ui = true
      cluster_addr = "http://${pkTailscaleIp}:8201"
      api_addr = "http://${pkTailscaleIp}:8200"
      service_registration "consul" {
        address = "http://${pkTailscaleIp}:8500"
      }
    '';
  };

  systemd.services.nirn-proxy = let
    package = (pkgs.callPackage ../packages/nirn-proxy.nix {});
  in {
    description = "Nirn Discord ratelimit proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "consul.service" ];

    path = [ package pkgs.consul ];

    # register/deregister from consul
    # needs to be _local_ agent
    postStart = ''
      CONSUL_HTTP_ADDR=http://${pkTailscaleIp}:8500 consul services register -name=nirn-proxy -id=nirn-proxy-${hostname} -port=8081
    '';
    postStop = ''
      CONSUL_HTTP_ADDR=http://${pkTailscaleIp}:8500 consul services deregister -id=nirn-proxy-${hostname}
    '';

    environment = {
      PORT = "8002";
      METRICS_PORT = "9002";
      BIND_IP = "${pkTailscaleIp}";
      CLUSTER_DNS = "nirn-proxy.service.consul";
    };

    serviceConfig = {
      ExecStart = "${package}/bin/nirn-proxy";
      User = "nirn";
      DynamicUser = true;
    };
  };

  environment.systemPackages = [
    pkgs.vault-bin # ???
  ];
}
