{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../nixosModules/edge.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  fileSystems."/boot" = { device = "/dev/vda1"; fsType = "vfat"; };
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = { device = "/dev/vda2"; fsType = "ext4"; };
  swapDevices = [ { device = "/swapfile"; } ];

	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "70.34.216.227/23" ];
		gateway = [ "70.34.216.1" ];
	};

  pkTailscaleIp = "100.120.109.26";

	system.stateVersion = "24.04";
}
