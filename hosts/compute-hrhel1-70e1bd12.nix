{ inputs, pkgs, lib, config, ... }:

{
  imports = [
    ../nixosModules/worker.nix
  ];

  hardware.cpu.amd.updateMicrocode = true;
  boot.initrd.availableKernelModules = [ "nvme" "ahci" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems = {
    "/" = { device = "/dev/disk/by-label/root"; fsType = "ext4"; };
    "/boot" = { device = "/dev/disk/by-label/boot"; fsType = "vfat"; };
  };

  pkTailscaleIp = "100.77.98.43";

  systemd.network.networks."eth0" = {
    matchConfig = { Name = "eth0"; };
    address = [ "65.108.12.49/26" ];
    gateway = [ "65.108.12.1" ];
  };

  system.stateVersion = "24.04";
}
