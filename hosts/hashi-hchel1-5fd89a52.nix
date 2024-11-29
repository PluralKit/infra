{ inputs, pkgs, lib, modulesPath, ... }:

{
	imports = [
		(modulesPath + "/profiles/qemu-guest.nix")
    ../nixosModules/seaweedfs.nix
    ../nixosModules/hashi.nix
	];

	boot.loader.grub.device = "/dev/sda";
	boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
	boot.initrd.kernelModules = [ "nvme" ];
	fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "95.216.154.82/32" ];
		gateway = [ "172.31.1.1" ];
		routes = [
			{ routeConfig = { Destination = "172.31.1.1/32"; Scope = "link"; }; }
		];
	};

  pkTailscaleIp = "100.120.65.72";

  seaweedMaster = true;

	system.stateVersion = "24.04";
}
