{ inputs, pkgs, lib, modulesPath, ... }:

{
	imports = [
		../../nixosModules/hashi.nix
		(modulesPath + "/profiles/qemu-guest.nix")
	];

	boot.loader.grub.device = "/dev/sda";
	boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
	boot.initrd.kernelModules = [ "nvme" ];
	fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

	networking.hostId = "bb0a8212";	
	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "188.245.126.196/32" ];
		gateway = [ "172.31.1.1" ];
		routes = [
			{ routeConfig = { Destination = "172.31.1.1/32"; Scope = "link"; }; }
		];
	};

	pkTailscaleIp = "100.82.64.16";

	system.stateVersion = "24.04";
}
