{ lib, pkgs, config, ... }:

{
  services.vmagent = {
    enable = true;
    extraArgs = [ "-enableTCP6" ];
    remoteWrite.url = "http://vm.svc.pluralkit.net/insert/0/prometheus/api/v1/write";
    prometheusConfig = {
      scrape_configs = [
        {
          job_name = "consul";
          consul_sd_configs = [{
            server = "${config.pkTailscaleIp}:8500";
            services = [ "metrics" ];
            filter = "Node == \"${config.networking.hostName}\"";
          }];
        }
        {
          job_name = "node_exporter";
          static_configs = [{
            targets = [ "http://${config.networking.hostName}.vpn.pluralkit.net:9100" ];
          }];
        }
      ];
    };
  };

  systemd.services.vmagent = {
    after =  [ "consul.service" ];
    requires =  [ "consul.service" ];
    serviceConfig.Restart = lib.mkForce "always";
    unitConfig.StartLimitIntervalSec = lib.mkForce 0;
  };

  environment.etc."vector-node-exporter.toml".text = ''
    sources.host.type = "host_metrics"

    [sinks.prometheus]
    type = "prometheus_exporter"
    inputs = [ "host" ]
    address = "${config.pkTailscaleIp}:9100"
  '';

  systemd.services.vector-node-exporter = {
    enable = true;
    description = "Vector.dev (host metrics exporter)";
    wantedBy = [ "multi-user.target" ];
    after = [ "consul.service" ];
    requires = [ "consul.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.vector}/bin/vector -w --config /etc/vector-node-exporter.toml";
      User = "root";
      Restart = "always";
      StateDirectory = "vector-metrics";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    };
    unitConfig.StartLimitIntervalSec = 0;
  };

  pkServerChecks = [
    { type = "systemd_service_running"; value = "vector-node-exporter"; }
    { type = "systemd_service_running"; value = "vmagent"; }
  ];
}
