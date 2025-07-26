{ inputs, pkgs, lib, config, modulesPath, ... }:

{
	imports = [
		(modulesPath + "/profiles/qemu-guest.nix")
		../nixosModules/o11y.nix
	];

	boot.loader.grub.device = "/dev/sda";
	boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
	boot.initrd.kernelModules = [ "nvme" ];
	fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "5.78.76.144/32" ];
		gateway = [ "172.31.1.1" ];
		routes = [
			{ Destination = "172.31.1.1/32"; Scope = "link"; }
		];
	};

	pkTailscaleIp = "100.71.144.27";

	system.stateVersion = "24.04";
}
