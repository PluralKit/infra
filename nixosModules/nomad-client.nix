{ lib, pkgs, config, ... }:

{
  systemd.services.nomad = {
    after = [ "consul.service" ];
    requires = [ "consul.service" ];
    serviceConfig.Restart = lib.mkForce "always";
    unitConfig.StartLimitIntervalSec = lib.mkForce 0;
  };
  services.nomad = {
    enable = true;
    dropPrivileges = false;
    settings = {
      bind_addr = "${config.pkTailscaleIp}";
      client = {
        enabled = true;
        servers = ["hashi.svc.pluralkit.net"];
        node_class = lib.mkDefault "changeme";
      };
      consul.address = "http://${config.pkTailscaleIp}:8500";
      vault = {
        enabled = true;
        address = "http://active.vault.service.consul:8200";
      };
      plugin.docker.config.allow_privileged = true;
    };
  };
}
