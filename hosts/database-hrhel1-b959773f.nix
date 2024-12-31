{ inputs, pkgs, lib, config, ... }:

{
  imports = [
    ../nixosModules/observability.nix
    ../nixosModules/database.nix
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

  pkTailscaleIp = "100.96.216.62";

  systemd.network.networks."eth0" = {
    matchConfig = { Name = "eth0"; };
    address = [ "95.217.79.59/26" ];
    gateway = [ "95.217.79.1" ];
  };

  system.stateVersion = "24.04";

  # databases
  fileSystems."/mnt/appdata" = { device = "/dev/disk/by-label/appdata"; fsType = "ext4"; };
  fileSystems."/mnt/observability" = { device = "/dev/disk/by-label/observability"; fsType = "ext4"; };
}
