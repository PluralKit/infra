{ lib, pkgs, config, ... }:

{
  services.vmagent = {
    enable = true;
    extraArgs = [ "-enableTCP6" ];
    remoteWrite.url = "http://vm.svc.pluralkit.net/insert/0/prometheus/api/v1/write";
    prometheusConfig = {
      global.scrape_interval = "15s";
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
          job_name = "prometheus-node-exporter";
          static_configs = [{
            targets = ["http://${config.networking.hostName}.vpn.pluralkit.net:9100/metrics"];
          }];
        }
      ];
    };
  };

  systemd.services.vmagent = {
    serviceConfig.Restart = lib.mkForce "always";
    unitConfig.StartLimitIntervalSec = lib.mkForce 0;
  };

  systemd.services.prometheus-node-exporter = {
    serviceConfig.Restart = lib.mkForce "always";
  };
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "${config.pkTailscaleIp}";
  };

  # this one is dumb: prometheus-node-exporter doesn't have good cpu metrics
  # so we set up an entirely separate exporter just to get a single host_logical_cpus metric
  # maybe see if we can fix this at some point?
  environment.etc."vector-cpu-metrics.toml".text = ''
[sources.host]
type = "host_metrics"

[sinks.victoriametrics]
  type = "prometheus_remote_write"
  inputs = ["host"]
  endpoint = "http://vm.svc.pluralkit.net/insert/0/prometheus/api/v1/write"
  healthcheck.enabled = false
  '';

  systemd.services.vector-cpu-metrics = {
    description = "Vector.dev (CPU metrics scrape)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.vector}/bin/vector --config /etc/vector-cpu-metrics.toml";
      Restart = "always";
      StateDirectory = "vector-metrics";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    };
    unitConfig.StartLimitIntervalSec = 0;
  };

  pkServerChecks = [
    { type = "systemd_service_running"; value = "prometheus-node-exporter"; }
    { type = "systemd_service_running"; value = "vmagent"; }
    { type = "systemd_service_running"; value = "vector-cpu-metrics"; }
  ];
}
