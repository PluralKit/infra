{ pkgs, lib, config, ... }:

with lib;

let
  postgresUid = 418;
  postgresGid = 418;

  pluralkit-scripts = pkgs.callPackage ../packages/pluralkit-scripts {};

  toStr = value:
    if true == value then "yes"
    else if false == value then "no"
    else if isString value then "'${lib.replaceStrings ["'"] ["''"] value}'"
    else toString value;

in
name:
{ package
, dataDir
, listenPort
, backupSettings ? {}
, extraSettings ? {}
, extraPgHba ? []
, extraListen ? []
, initDbArgs ? []
, ...
}:
let
  configFile = pkgs.writeTextDir "postgresql.conf"
    (concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") pgSettings));

  pgHba = [
     "local all all peer"
     "local replication all peer"
     "host all all 127.0.0.1/32 md5"
     "host all all 172.17.0.1/24 md5"
     "host all all ::1/128 md5"
     "host replication pkrepluser 100.64.0.0/10 md5"
     "host all all 100.64.0.0/10 md5"
  ];

  authFile = pkgs.writeText "pg_hba.conf" (builtins.concatStringsSep "\n" (pgHba ++ extraPgHba));

  walArchiveSettings = if backupSettings != {} then {
    archive_mode = "yes";
    archive_command = "${pluralkit-scripts}/bin/pk-walg ${backupSettings.s3dir} ${toString listenPort} ${backupSettings.database} wal-push %p";
    archive_timeout = 60;
  } else {};

  pgListen = [ "localhost" config.pkTailscaleIp ];

  pgSettings = {
    port = listenPort;
    listen_addresses = builtins.concatStringsSep ", " (pgListen ++ extraListen);
    log_line_prefix = "${name}";
    log_destination = "stderr";
    hba_file = "${authFile}";
    max_connections = 2000;
    log_min_duration_statement = 1000;
  } // extraSettings // walArchiveSettings;

in
{
  description = "PostgreSQL - ${name}";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" "consul.service" ];

  unitConfig.RequiresMountsFor = "${dataDir}";
  environment.PGDATA = "${dataDir}";
  path = [ package ];

  preStart =
    ''
      if ! test -e ${dataDir}/PG_VERSION; then
        rm -f ${dataDir}/*.conf
        initdb -U postgres ${concatStringsSep " " initDbArgs}
      fi

      rm -f ${dataDir}/postgresql.conf
      cp "${configFile}/postgresql.conf" "${dataDir}/postgresql.conf"
    '';

  serviceConfig = {
    User = "postgres";
    Group = "postgres";
    Type = "notify";

    RuntimeDirectory = "postgresql";
    RuntimeDirectoryPreserve = "yes";

    KillSignal = "SIGINT";
    KillMode = "mixed";
    TimeoutSec = 120;

    ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    # `primary-conninfo` is a regular postgresql connection string
    ExecStart = if backupSettings != {} then pkgs.writeShellScript "run-postgres" ''
      if [ -f /etc/pluralkit/postgres-${backupSettings.s3dir}-primary-conninfo ]; then
        touch ${dataDir}/standby.signal
        exec ${package}/bin/postgres \
          --primary-conninfo="$(cat /etc/pluralkit/postgres-${backupSettings.s3dir}-primary-conninfo)" \
          --restore_command='${pluralkit-scripts}/bin/pk-walg ${backupSettings.s3dir} ${toString listenPort} ${backupSettings.database} wal-fetch "%f" "%p"'
      else
        rm ${dataDir}/standby.signal || true
        exec ${package}/bin/postgres
      fi
    '' else "${package}/bin/postgres";
  };
}
