{ lib, pkgs, config, ... }:

{
  services.vmagent = {
    enable = true;
    extraArgs = [ "-enableTCP6" ];
    remoteWrite = {
      url = "https://insert.fly-metrics.net/api/v1/write";
      basicAuthUsername = "fly-804566";
      basicAuthPasswordFile = "/etc/pluralkit/metrics-password";
    };
    prometheusConfig = {
      global.scrape_interval = "15s";
      scrape_configs = [
        {
          job_name = "prometheus-node-exporter";
          static_configs = [{
            targets = ["http://${config.networking.hostName}.vpn.pluralkit.net:9100/metrics"];
          }];
          metric_relabel_configs = [{
            action = "replace";
            source_labels = ["__name__"];
            regex = "node_cpu_seconds_total";
            target_label = "__name__";
            replacement = "pluralkit_cpu_seconds_total";
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
    after = [ "tailscale-ready.service" ];
    wants  = [ "tailscale-ready.service" ];
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
  endpoint = "https://insert.fly-metrics.net/api/v1/write"
  auth.strategy = "basic"
  auth.user = "fly-804566"
  auth.password = "''${INGEST_TOKEN}"
  healthcheck.enabled = false
  '';

  systemd.services.vector-cpu-metrics = {
    description = "Vector.dev (CPU metrics scrape)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "vector-logs" ''
          export INGEST_TOKEN=$(cat /etc/pluralkit/metrics-password)
          exec ${pkgs.vector}/bin/vector --config /etc/vector-cpu-metrics.toml
        '';
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
