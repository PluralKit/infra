{ inputs
, pkgs
, lib
, ...
}:

{
  fileSystems."/var/lib/prometheus2" = {
    device = "/srv/data1/prometheus";
    options = [ "bind" ];
  };
  services.prometheus = {
    enable = true;
    scrapeConfigs = [
      { job_name = "http-proxy"; static_configs = [{ targets = [ "10.0.0.2:9000" ]; }];  }
    ];
  };

  services.influxdb = {
    enable = true;
    dataDir = "/srv/data1/influxdb";
  };

  services.grafana = {
    enable = true;
    dataDir = "/srv/data1/grafana/";
    settings.server.domain = "grafana.pluralkit.me";
    settings.server.http_addr = "10.0.1.6";
  };
}
