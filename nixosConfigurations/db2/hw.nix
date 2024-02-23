{ config
, lib
, pkgs
, ...
}:

{
  hardware.cpu.amd.updateMicrocode = true;
  boot.initrd.availableKernelModules = [ "nvme" "ahci" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = false;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/330d2b7b-1ac3-4cac-a281-970fc59546b7";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CD7E-3B9C";
    fsType = "vfat";
  };

  fileSystems."/srv" = {
    device = "/dev/disk/by-uuid/70754f40-5670-4fee-8a38-da8714252783";
    fsType = "xfs";
  };

  fileSystems."/srv/data2" = {
    device = "/dev/disk/by-uuid/40859153-0841-4784-bc70-db2c262773aa";
    fsType = "xfs";
  };

  swapDevices = [];
}
