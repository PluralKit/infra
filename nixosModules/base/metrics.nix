{ lib, pkgs, config, ... }:

{
	services.consul-template.instances.metrics = {
    enable = true;
    settings.consul.address = "http://127.0.0.1:8500";
    settings.template = [ {
      source = (pkgs.writeTextFile {
        name = "vector-metrics.tpl";
        text = ''
[sources.node-exporter]
type = "prometheus_scrape"
endpoints = [ "http://127.0.0.1:9100/metrics" ]
instance_tag = "host"

[transforms.node-exporter-tagged]
type = "remap"
inputs = ["node-exporter"]
source = ".tags.job = \"node-exporter\""

{{ range service "metrics" }}
  {{ if eq .Node "${config.networking.hostName}" }}

[sources.{{ .ID }}]
type = "prometheus_scrape"
endpoints = [ "http://[{{ .Address }}]:{{ .Port }}/metrics" ]

  {{ end }}
{{ end }}

[sinks.prometheus]
type = "prometheus_remote_write"
inputs = [
        "node-exporter-tagged",
{{ range $srv := service "metrics" }}
    {{ if eq .Node "${config.networking.hostName}" }}
        "{{ .ID }}",
    {{ end }}
{{ end }}
]
endpoint = "http://observability.svc.pluralkit.net:9090/api/v1/write"
healthcheck.enabled = false
        '';
      });
      destination = "/run/vector-metrics.toml";
    } ];
  };
  systemd.services.consul-template-metrics = {
    after =  [ "consul.service" ];
    requires =  [ "consul.service" ];
    serviceConfig.Restart = lib.mkForce "always";
    unitConfig.StartLimitIntervalSec = lib.mkForce 0;
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  systemd.services.vector-metrics = {
    description = "Vector.dev (metrics scrape)";
    wantedBy = [ "multi-user.target" ];
    after = [ "consul-template-metrics.service" ];
    requires = [ "consul-template-metrics.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.vector}/bin/vector --config /run/vector-metrics.toml";
      DynamicUser = true;
      Restart = "always";
      StateDirectory = "vector-metrics";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    };
    unitConfig.StartLimitIntervalSec = 0;
  };

  pkServerChecks = [
    { type = "systemd_service_running"; value = "prometheus-node-exporter"; }
    { type = "systemd_service_running"; value = "consul-template-metrics"; }
    { type = "systemd_service_running"; value = "vector-metrics"; }
  ];
}
