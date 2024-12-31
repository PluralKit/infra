{ lib, pkgs, config, ... }:

{
	services.consul-template.instances.metrics = {
    enable = true;
    settings.consul.address = "http://${config.pkTailscaleIp}:8500";
    settings.template = [ {
      source = (pkgs.writeTextFile {
        name = "vector-metrics.tpl";
        text = ''
[sources.host]
type = "host_metrics"

[sources.node-exporter]
type = "prometheus_scrape"
endpoints = [ "http://${config.networking.hostName}.vpn.pluralkit.net:9100/metrics" ]
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
instance_tag = "host"

  {{ end }}
{{ end }}

[sinks.victoriametrics]
type = "prometheus_remote_write"
inputs = [
        "host",
{{ range $srv := service "metrics" }}
    {{ if eq .Node "${config.networking.hostName}" }}
        "{{ .ID }}",
    {{ end }}
{{ end }}
]
endpoint = "http://vm.svc.pluralkit.net/insert/0/prometheus/api/v1/write"
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

  systemd.services.prometheus-node-exporter = {
    after =  [ "consul.service" ];
    requires =  [ "consul.service" ];
    serviceConfig.Restart = lib.mkForce "always";
  };
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "${config.pkTailscaleIp}";
  };

  systemd.services.vector-metrics = {
    description = "Vector.dev (metrics scrape)";
    wantedBy = [ "multi-user.target" ];
    after = [ "consul-template-metrics.service" ];
    requires = [ "consul-template-metrics.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.vector}/bin/vector -w --config /run/vector-metrics.toml";
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
