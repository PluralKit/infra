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

  mkPostgresService = name:
    { package
    , dataDir
    , listenPort
    , backupSettings ? {}
    , extraSettings ? {}
    , initDbArgs ? []
    , ...
    }:
      let
        configFile = pkgs.writeTextDir "postgresql.conf"
          (concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") pgSettings));

        authFile = pkgs.writeText "pg_hba.conf"
          ''
            local all all peer
            local replication all peer
            host all all 127.0.0.1/32 md5
            host all all ::1/128 md5
            host replication pkrepluser 100.64.0.0/10 md5
            host all all 100.64.0.0/10 md5
          '';

        walArchiveSettings = if backupSettings != {} then {
          archive_mode = "yes";
          archive_command = "${pluralkit-scripts}/bin/pk-walg ${backupSettings.s3dir} ${toString listenPort} ${backupSettings.database} wal-push %p";
          archive_timeout = 60;
        } else {};

        pgSettings = {
          port = listenPort;
          listen_addresses = "localhost, ${config.pkTailscaleIp}";
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
      };
in
{
  # redis nixpkgs module does not allow choosing data location :/
  # also see below in systemd.services
  fileSystems."/var/lib/redis-pluralkit" = {
    device = "/mnt/appdata/redis";
    options = [ "bind" ];
  };
  services.redis.servers."pluralkit" = {
    enable = true;
    bind = "127.0.0.1 ${config.pkTailscaleIp}";
    port = 6379;
    openFirewall = lib.mkForce false;
    settings = {
      protected-mode = false;
      io-threads = 8;
      tcp-backlog = 511;
    };
  };

  users.groups.postgres.gid = postgresGid;
  users.users.postgres = {
    name = "postgres";
    uid = postgresUid;
    group = "postgres";
    description = "PostgreSQL server user for PluralKit";
    createHome = false;
    isSystemUser = true;
    useDefaultShell = true;
  };

  systemd.services = {
    redis-pluralkit.after = [ "consul.service" "var-lib-redis-pluralkit.mount" ];  

    pluralkit-db-data = mkPostgresService "pluralkit-db-data" {
      package = pkgs.postgresql_14;
      dataDir = "/mnt/appdata/postgres-data";
      listenPort = 5432;
      extraSettings = {
        shared_buffers = "20GB";
        effective_cache_size = "10GB";
        min_wal_size = "80MB";
        max_wal_size = "1GB";
      };
      backupSettings = {
        s3dir = "data";
        database = "pluralkit";
      };
    };

    pluralkit-db-messages = mkPostgresService "pluralkit-db-messages" {
      package = pkgs.postgresql_14;
      dataDir = "/mnt/appdata/messages";
      listenPort = 5434;
      extraSettings = {
        max_locks_per_transaction = 256;
        shared_buffers = "12GB";
        effective_cache_size = "4GB";
        min_wal_size = "80MB";
        max_wal_size = "1GB";
      };
      backupSettings = {
        s3dir = "messages";
        database = "messages";
      };
    };

    pluralkit-db-utils = mkPostgresService "pluralkit-db-utils" {
      package = pkgs.postgresql_17;
      dataDir = "/mnt/appdata/utils";
      listenPort = 5435;
    };
  };

  pkServerChecks = [
    { type = "systemd_service_running"; value = "redis-pluralkit"; }
    { type = "systemd_service_running"; value = "pluralkit-db-data"; }
    { type = "systemd_service_running"; value = "pluralkit-db-messages"; }
  ];
}
