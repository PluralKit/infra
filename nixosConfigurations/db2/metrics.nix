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
    extraFlags = [ "--web.enable-remote-write-receiver" "--web.enable-admin-api" ];
  };

  services.influxdb = {
    enable = true;
    dataDir = "/srv/data1/influxdb";
  };

  services.grafana = {
    enable = true;
    dataDir = "/srv/data1/grafana/";
    settings.server.domain = "grafana.pluralkit.me";
    settings.server.http_addr = "100.83.67.99";
  };
}
