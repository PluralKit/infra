{ inputs, pkgs, lib, modulesPath, ... }:

{
	imports = [
		(modulesPath + "/profiles/qemu-guest.nix")
    ../nixosModules/hashi.nix
	];

	boot.loader.grub.device = "/dev/sda";
	boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
	boot.initrd.kernelModules = [ "nvme" ];
	fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "37.27.8.234/32" ];
		gateway = [ "172.31.1.1" ];
		routes = [
			{ Destination = "172.31.1.1/32"; Scope = "link"; }
		];
	};

  pkTailscaleIp = "100.113.220.49";

	system.stateVersion = "24.04";
}

