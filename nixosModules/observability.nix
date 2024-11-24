{ pkgs, lib, config, ... }:

{
  # note: users are forcefully manually configured here because i can't figure
  # out how to get the permissions to work on custom data dirs otherwise
  # this is probably not how it should be set up...

  services.opensearch = {
    enable = true;
    settings."network.host" = "${config.pkTailscaleIp}";
    dataDir = "/mnt/observability/opensearch/";
    extraJavaOptions = [ "-Xmx32g"   "-Djava.net.preferIPv4Stack=true" ];
  };
  systemd.services.opensearch.serviceConfig.DynamicUser = lib.mkForce false;
  users.users.opensearch = {
    isSystemUser = true;
    group = "opensearch";
  };
  users.groups.opensearch = {};
  systemd.services.opensearch = {
    after = [ "consul.service" ];
    requires = [ "consul.service" ];
  };

  # configured by manually overriding ExecStart
  # because nixpkgs hardcodes storage path
  services.victoriametrics = {
    enable = true;
    listenAddress = "${config.pkTailscaleIp}:9090";
  };
  systemd.services.victoriametrics = {
    after = [ "consul.service" ];
    requires = [ "consul.service" ];
  };
  systemd.services.victoriametrics.serviceConfig = {
    ExecStart = lib.mkForce ''
      ${pkgs.victoriametrics}/bin/victoria-metrics \
        -storageDataPath=/mnt/observability/victoriametrics/ \
        -httpListenAddr ${config.pkTailscaleIp}:9090 \
        -retentionPeriod 1
    '';
    User = "victoriametrics";
    DynamicUser = lib.mkForce false;
  };
  users.users.victoriametrics = {
    isSystemUser = true;
    group = "victoriametrics";
  };
  users.groups.victoriametrics = {};

  pkServerChecks = [
    { type = "systemd_service_running"; value = "opensearch"; }
    { type = "systemd_service_running"; value = "victoriametrics"; }
  ];
}
