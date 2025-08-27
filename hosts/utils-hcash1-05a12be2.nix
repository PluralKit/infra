{ inputs, pkgs, lib, config, modulesPath, ... }:

let
  postgresUid = 418;
  postgresGid = 418;

  mkPostgresService = import ../nixosModules/database.nix { inherit lib pkgs config; };

  pkWorkerSubnet = let
    pt1 = builtins.substring 0 4 config.networking.hostId;
    pt2 = builtins.substring 4 8 config.networking.hostId;
  in "fdef:${pt1}:${pt2}::/80";
in
{
	imports = [
		(modulesPath + "/profiles/qemu-guest.nix")
		../nixosModules/statuspage.nix
	];

	boot.loader.grub.device = "/dev/sda";
	boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
	boot.initrd.kernelModules = [ "nvme" ];
	fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "5.161.43.226/32" ];
		gateway = [ "172.31.1.1" ];
		routes = [
			{ Destination = "172.31.1.1/32"; Scope = "link"; }
		];
	};

  pkTailscaleIp = "100.79.33.60";

	# todo: put wg config here
	networking.firewall.trustedInterfaces = [ "docker0" "fly-wg" ];

	system.stateVersion = "24.04";

  virtualisation.docker.daemon.settings = {
    experimental = true;
    ip6tables = true;
    ipv6 = true;
    fixed-cidr-v6 = pkWorkerSubnet;
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

	systemd.services.pluralkit-db-utils = mkPostgresService "pluralkit-db-utils" {
		package = pkgs.postgresql_17;
		dataDir = "/srv/postgres-utils";
		listenPort = 5432;
		extraListen = [ "fdaa:9:e856:a7b:8cfe:0:a:2" ];
		extraPgHba = [ "host all all fdaa:9:e856::/48 md5" ];
	};

	services.redis.servers.utils = {
		enable = true;
		bind = "127.0.0.1 ${config.pkTailscaleIp}";
		port = 6379;
		openFirewall = lib.mkForce false;
		settings = {
			protected-mode = "no";
		};
	};

	virtualisation.docker.enable = true;
}
