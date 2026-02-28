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

	virtualisation.docker.enable = true;
}
