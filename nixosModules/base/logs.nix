{ lib, pkgs, config, ... }:

{
  options = with lib.types; {
    pkLogTargets = lib.mkOption {
      type = listOf str;
    };
  };

  config = {
    pkLogTargets = [
      ''
        [sources.journald]
        type = "journald"

        [sinks.opensearch-journald]
        type = "elasticsearch"
        api_version = "v8"
        inputs = ["journald"]
        bulk.index = "journald"
        endpoints = ["http://es.svc.pluralkit.net"]
      ''
    ];

    systemd.services.vector = {
      description = "Vector.dev (logs)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "tailscale-ready.service" ];
      wants  = [ "tailscale-ready.service" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.vector}/bin/vector --config ${pkgs.writeTextFile {
          name = "vector.conf";
          text = lib.concatStrings config.pkLogTargets;
        }}";
        DynamicUser = true;
        Group = "docker";
        Restart = "always";
        StateDirectory = "vector";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        SupplementaryGroups = "systemd-journal";
      };
      unitConfig = {
        StartLimitIntervalSec = 10;
        StartLimitBurst = 5;
      };
    };
    pkServerChecks = [{ type = "systemd_service_running"; value = "vector"; }];
  };
}
