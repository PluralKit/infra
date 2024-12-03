{ config, inputs, pkgs, lib, modulesPath, ... }:

let
  hostname = config.networking.hostName;
  pkTailscaleIp = config.pkTailscaleIp;
in {
  # for hashistack (nomad/consul/vault) servers

  nixpkgs.config.permittedInsecurePackages = [
    "vault-bin-1.15.6"
  ];

  # always talk to local host on hashi servers
  environment.variables = {
    NOMAD_ADDR = lib.mkForce "http://${pkTailscaleIp}:4646";
    CONSUL_HTTP_ADDR = lib.mkForce "http://${pkTailscaleIp}:8500";
    VAULT_ADDR = lib.mkForce "http://${pkTailscaleIp}:8200";
  };

  systemd.services.nomad = {
    after = [ "consul.service" ];
    requires = [ "consul.service" ];
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
    extraSettingsPaths = [ "/etc/pluralkit/nomad-vault-token.hcl" ];
  };

  # addition to base
  services.consul = {
    enable = true;
    extraConfig = {
      ui_config.enabled = true;
      server = true;
      addresses.http = "${pkTailscaleIp}";
    };
  };

  systemd.services.vault = {
    after = [ "consul.service" ];
    requires = [ "consul.service" ];
  };
  services.vault = {
    enable = true;
    package = pkgs.vault-bin;
    address = "${pkTailscaleIp}:8200";
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

  pkServerChecks = [
    { type = "systemd_service_running"; value = "nomad"; }
    { type = "systemd_service_running"; value = "vault"; }
    # { type = "script"; value = (pkgs.writeShellScript "check-vault-unsealed" ''
    #   #!/bin/sh
    #   export PATH=/run/current-system/sw/bin/:$PATH
    #   export VAULT_ADDR=http://${config.pkTailscaleIp}:8200
    #   export VAULT_TOKEN=$(cat /etc/pluralkit/nomad-vault-token.hcl | grep token | awk '{print $3}' | jq -r)

    #   # exits 2 if vault is sealed
    #   # 0 if unsealed
    #   vault operator key-status
    # ''); }
  ];

  environment.systemPackages = [
    pkgs.vault-bin # ???
  ];

  # hashi hosts listen on pkTailscaleIp for consul api, so override consul-template config
  services.consul-template.instances.metrics.settings.consul.address = lib.mkForce "http://${config.pkTailscaleIp}:8500";
 }
