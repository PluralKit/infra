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

	networking.hostId = "b1ad067f";
	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "188.34.156.231/32" ];
		gateway = [ "172.31.1.1" ];
		routes = [
			{ routeConfig = { Destination = "172.31.1.1/32"; Scope = "link"; }; }
		];
	};

	pkTailscaleIp = "100.86.170.19";

	system.stateVersion = "24.04";
}
