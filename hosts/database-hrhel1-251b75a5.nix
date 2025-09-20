{ inputs, pkgs, lib, config, ... }:

let
  postgresUid = 418;
  postgresGid = 418;

  mkPostgresService = import ../nixosModules/database.nix { pkgs = pkgs; lib = lib; config = config; };
in
{
  hardware.cpu.amd.updateMicrocode = true;
  boot.initrd.availableKernelModules = [ "nvme" "ahci" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems = {
    "/" = { device = "/dev/disk/by-label/root"; fsType = "ext4"; };
    "/boot" = { device = "/dev/disk/by-label/boot"; fsType = "vfat"; };
  };

  pkTailscaleIp = "100.115.185.127";

  networking.firewall.trustedInterfaces = [ "fly" ];

  # not sure why this is needed
  networking.usePredictableInterfaceNames = false;

  systemd.network.networks."eth0" = {
    matchConfig = { Name = "eth0"; };
    address = [ "37.27.117.165/26" ];
    gateway = [ "37.27.117.129" ];
  };

  networking.wg-quick.interfaces.fly = {
    address = [ "fdaa:9:e856:a7b:35c:0:a:102/120" ];
    privateKeyFile = "/opt/fly-wg-privkey";
    peers = [{
      publicKey = "tyYPi0DmwNDs3YEhnm4CeNy5I9m2QSsdry4H46Zfr3M=";
      endpoint = "arn1.gateway.6pn.dev:51820";
      allowedIPs = [ "fdaa:9:e856::/48" ];
      persistentKeepalive = 15;
    }];
  };

  system.stateVersion = "25.05";

  # databases
  fileSystems."/mnt/appdata" = { device = "/dev/disk/by-label/appdata"; fsType = "ext4"; };

  services.redis.servers."pluralkit" = {
    enable = true;
    bind = "127.0.0.1 ${config.pkTailscaleIp} ${(builtins.head (lib.splitString "/" (builtins.head config.networking.wg-quick.interfaces.fly.address)))}";
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
    redis-pluralkit = {
      after = [ "tailscale-ready.service" ];
      wants = [ "tailscale-ready.service" ];
    };

    pluralkit-db-data = mkPostgresService "pluralkit-db-data" {
      package = pkgs.postgresql_14;
      dataDir = "/mnt/appdata/postgres-data";
      listenPort = 5432;
      extraSettings = {
        shared_buffers = "50GB";
        effective_cache_size = "40GB";
        min_wal_size = "80MB";
        max_wal_size = "1GB";
      };
      backupSettings = {
        s3dir = "data";
        database = "pluralkit";
      };
      extraListen = [ (builtins.head (lib.splitString "/" (builtins.head config.networking.wg-quick.interfaces.fly.address))) ];
      extraPgHba = [ "host all all ${builtins.head (builtins.head config.networking.wg-quick.interfaces.fly.peers).allowedIPs} md5" ];
    };

    pluralkit-db-messages = mkPostgresService "pluralkit-db-messages" {
      package = pkgs.postgresql_14;
      dataDir = "/srv/messages";
      listenPort = 5434;
      extraSettings = {
        max_locks_per_transaction = 256;
        shared_buffers = "32GB";
        effective_cache_size = "16GB";
        min_wal_size = "80MB";
        max_wal_size = "1GB";
      };
      backupSettings = {
        s3dir = "messages";
        database = "messages";
      };
      extraListen = [ (builtins.head (lib.splitString "/" (builtins.head config.networking.wg-quick.interfaces.fly.address))) ];
      extraPgHba = [ "host all all ${builtins.head (builtins.head config.networking.wg-quick.interfaces.fly.peers).allowedIPs} md5" ];
    };
  };

  pkServerChecks = [
    { type = "systemd_service_running"; value = "redis-pluralkit"; }
    { type = "systemd_service_running"; value = "pluralkit-db-data"; }
    { type = "systemd_service_running"; value = "pluralkit-db-messages"; }
  ];
}
