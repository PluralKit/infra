{ pkgs, config, ... }:

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
endpoints = [ "http://${config.pkTailscaleIp}:9100/metrics" ]
instance_tag = "host"

[transforms.node-exporter-tagged]
type = "remap"
inputs = ["node-exporter"]
source = ".tags.job = \"node-exporter\""

{{ $lnode := node }}

{{ range service "metrics" }}
  {{ if eq .Address $lnode.Node.Address }}

[sources.{{ .ID }}]
type = "prometheus_scrape"
endpoints = [ "http://{{ $lnode.Node.Address }}:{{ .Port }}/metrics" ]

  {{ end }}
{{ end }}

[sinks.prometheus]
type = "prometheus_remote_write"
inputs = [
        "node-exporter-tagged",
{{ range $srv := service "metrics" }}
    {{ if eq .Address $lnode.Node.Address }}
        "{{ .ID }}",
    {{ end }}
{{ end }}
]
endpoint = "http://db.svc.pluralkit.net:9090/api/v1/write"
healthcheck.enabled = false
        '';
      });
      destination = "/run/vector-metrics.toml";
    } ];
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "${config.pkTailscaleIp}";
  };

  systemd.services.vector-metrics = {
    description = "Vector.dev (metrics scrape)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" "consul-template-metrics.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.vector}/bin/vector --config /run/vector-metrics.toml";
      DynamicUser = true;
      Restart = "always";
      StateDirectory = "vector-metrics";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    };
    unitConfig = {
      StartLimitIntervalSec = 10;
      StartLimitBurst = 5;
    };
  };
}
