{ lib, pkgs, ... }:
dbServiceName:
{ dbName, pgPort, listenPort }:
{
  description = "Prometheus PostgreSQL exporter - ${dbServiceName}";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" "tailscale-ready.service" "${dbServiceName}.service" ];
  wants  = [ "tailscale-ready.service" ];

  environment.DATA_SOURCE_NAME =
    "user=postgres_exporter host=/run/postgresql port=${toString pgPort} dbname=${dbName} sslmode=disable";
  serviceConfig = {
    User = "postgres_exporter";
    ExecStart = "${pkgs.prometheus-postgres-exporter}/bin/postgres_exporter"
      + " --web.listen-address=127.0.0.1:${toString listenPort}";
    Restart = "on-failure";
  };
}
