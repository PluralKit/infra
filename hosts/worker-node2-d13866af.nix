{ inputs, pkgs, lib, config, ... }:

let
in
{
  imports = [
		../nixosModules/k8s.nix
	];

  hardware.cpu.amd.updateMicrocode = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "usb_storage" "usbhid" "sr_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems = {
    "/" = { device = "/dev/disk/by-label/NIXROOT"; fsType = "ext4"; };
    "/boot" = { device = "/dev/disk/by-label/NIXBOOT"; fsType = "vfat"; };
  };

  pluralkit.bond-setup = {
    enable = true;

    bondAddresses = [ "192.168.20.11/24" ];
    bondGateway = "192.168.20.254";

    vlans = {
      "public" = {
        id = 10;
        addresses = [ "91.208.228.70/28" "2403:b4c0:5b07:2::1/48" ];
        gateway4 = "91.208.228.65";
        gateway6 = "2403:b4c0:5b07::1";
        metric = 100;
      };
      "k8s" = {
        id = 90;
        bridge = "br0";
      };
    };
  };

  pkTailscaleIp = "100.93.93.55";
  system.stateVersion = "25.05";

  services.pk-k3s.bridgeSubnet = "10.20.102.0/24";
}
