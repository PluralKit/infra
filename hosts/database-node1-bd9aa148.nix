{ inputs, pkgs, lib, config, ... }:

let
  postgresUid = 418;
  postgresGid = 418;

  mkPostgresService = import ../nixosModules/database.nix { pkgs = pkgs; lib = lib; config = config; };
in
{
  hardware.cpu.amd.updateMicrocode = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "usb_storage" "usbhid" "sr_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.swraid = {
    enable = true;
    mdadmConf = "ARRAY /dev/md0 level=raid1 num-devices=2 metadata=1.2 UUID=013e207e:6160fbd5:7eef3d59:91b4776e devices=/dev/nvme0n1p2,/dev/nvme1n1p2";
  };
  systemd.services."mdmonitor".environment = {
    MDADM_MONITOR_ARGS = "--scan --syslog";
  };

  environment.etc.crypttab = {
    mode = "0600";
    text = ''
      # <volume-name> <encrypted-device> [key-file] [options]
      appdata_storage UUID=37b0f87a-011f-4955-8208-257ff2d434eb /etc/pluralkit/appdata.key
    '';
  };

  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXROOT";
      fsType = "ext4";
    };
  fileSystems."/boot" = 
    { device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
    };
  fileSystems."/mnt/appdata" =
    { device = "/dev/disk/by-label/appdata";
      fsType = "ext4";
    };

  networking.usePredictableInterfaceNames = false;
  systemd.network = {
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
        };
        bondConfig = {
          Mode = "active-backup";
          TransmitHashPolicy = "layer3+4";
        };
      };
      "20-vlan10" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan10";
        };
        vlanConfig.Id = 10;
      };
    };

    networks = {
      "30-eth0" = {
        matchConfig.Name = "eth0";
        networkConfig.Bond = "bond0";
      };
      "30-eth1" = {
        matchConfig.Name = "eth1";
        networkConfig.Bond = "bond0";
      };
      "40-bond0" = {
        matchConfig.Name = "bond0";
        vlan = [
          "vlan10"
        ];

        address = [ "192.168.20.10/24" ];
        routes = [
          {
            Gateway = "192.168.20.254";
            Metric = 200;
          }
        ];

        networkConfig.LinkLocalAddressing = "no";
        linkConfig.RequiredForOnline = "carrier";
      };
      "50-vlan10" = {
        matchConfig.Name = "vlan10";
        
        address = [ "91.208.228.69/28" ];
        routes = [
          {
            Gateway = "91.208.228.65";
            Metric = 100;
          }
        ];
      };
    };
  };
  networking.firewall.trustedInterfaces = [ "bond0" ];

  pkTailscaleIp = "100.123.150.13";
  system.stateVersion = "25.05";

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
    redis-pluralkit = {
      after = [ "tailscale-ready.service" ];
      wants = [ "tailscale-ready.service" ];
    };

    # pluralkit-db-data = mkPostgresService "pluralkit-db-data" {
    #   package = pkgs.postgresql_14;
    #   dataDir = "/srv/postgres-data";
    #   listenPort = 5432;
    #   extraSettings = {
    #     shared_buffers = "50GB";
    #     effective_cache_size = "40GB";
    #     min_wal_size = "80MB";
    #     max_wal_size = "1GB";
    #   };
    #   backupSettings = {
    #     s3dir = "data";
    #     database = "pluralkit";
    #   };
    # };

    # pluralkit-db-messages = mkPostgresService "pluralkit-db-messages" {
    #   package = pkgs.postgresql_14;
    #   dataDir = "/srv/messages";
    #   listenPort = 5434;
    #   extraSettings = {
    #     max_locks_per_transaction = 256;
    #     shared_buffers = "32GB";
    #     effective_cache_size = "16GB";
    #     min_wal_size = "80MB";
    #     max_wal_size = "1GB";
    #   };
    #   backupSettings = {
    #     s3dir = "messages";
    #     database = "messages";
    #   };
    # };
  };

  pkServerChecks = [
    { type = "systemd_service_running"; value = "redis-pluralkit"; }
    # { type = "systemd_service_running"; value = "pluralkit-db-data"; }
    # { type = "systemd_service_running"; value = "pluralkit-db-messages"; }
  ];
}
