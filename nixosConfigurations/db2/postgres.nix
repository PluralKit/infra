{ pkgs
, lib
, ...
}:

with lib;

let
  postgresUid = 418;
  postgresGid = 418;

  toStr = value:
    if true == value then "yes"
    else if false == value then "no"
    else if isString value then "'${lib.replaceStrings ["'"] ["''"] value}'"
    else toString value;

  mkPostgresService = name:
    { package
    , dataDir
    , listenPort
    , extraSettings ? {}
    , authentication ? ""
    , initDbArgs ? []
    , ...
    }:
      let
        configFile = pkgs.writeTextDir "postgresql.conf"
          (concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") pgSettings));

        authFile = pkgs.writeText "pg_hba.conf"
          ''
            ${authentication}

            # default authentication values
            local all all peer
            host all all 127.0.0.1/32 md5
            host all all ::1/128 md5
          '';

        pgSettings = {
          port = listenPort;
          listen_addresses = "localhost";
          log_line_prefix = "${name}";
          log_destination = "stderr";
          hba_file = "${authFile}";
          max_connections = 2000;
          log_min_duration_statement = 1000;
        } // extraSettings;

      in
      {
        description = "PostgreSQL - ${name}";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        unitConfig.RequiresMountsFor = "${dataDir}";
        environment.PGDATA = "${dataDir}";
        path = [ package ];

        preStart =
          ''
            if ! test -e ${dataDir}/PG_VERSION; then
              rm -f ${dataDir}/*.conf
              initdb -U postgres ${concatStringsSep " " initDbArgs}
            fi

            ln -sfn "${configFile}/postgresql.conf" "${dataDir}/postgresql.conf"
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
          ExecStart = "${package}/bin/postgres";
        };
      };

in
{
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

  networking.firewall.interfaces."internal".allowedTCPPorts = [
    5432
    5433
    5434
  ];

  environment.systemPackages = with pkgs; [ borgmatic wal-g ];

  systemd.services =
    let
      listenAddresses = "127.0.0.1, 10.0.1.6";
      extraPgHba = ''
        host all all 10.0.0.0/24 md5
        host all all 10.0.1.0/24 md5
        host replication pkrepluser 10.0.1.3/32 md5
      '';

    in
    {
      pluralkit-db-messages = mkPostgresService "pluralkit-db-messages" {
        package = pkgs.postgresql_14;
        dataDir = "/srv/data2/pg-messages";
        listenPort = 5434;
        authentication = extraPgHba;
        extraSettings = {
          listen_addresses = listenAddresses;
          max_locks_per_transaction = 256;
          shared_buffers = "12GB";
          effective_cache_size = "4GB";
          max_wal_size = "1GB";
          min_wal_size = "80MB";
          archive_mode = "yes";
          archive_command = "/opt/wal-g wal-push %p";
          archive_timeout = 60;
        };
      };

      pluralkit-db-data = mkPostgresService "pluralkit-db-data" {
        package = pkgs.postgresql_14;
        dataDir = "/srv/data1/pg-data";
        listenPort = 5432;
        authentication = extraPgHba;
        extraSettings = {
          listen_addresses = listenAddresses;
          shared_buffers = "20GB";
          effective_cache_size = "10GB";
          min_wal_size = "80MB";
          max_wal_size = "1GB";
        };
      };

      pluralkit-db-stats = mkPostgresService "pluralkit-db-stats" {
        package = pkgs.postgresql_14.withPackages (f: with f; [ timescaledb ]);
        dataDir = "/srv/data1/pg-stats";
        listenPort = 5433;
        authentication = extraPgHba;
        extraSettings = {
          listen_addresses = listenAddresses;
          shared_preload_libraries = "timescaledb";
        };
      };
  };
}
