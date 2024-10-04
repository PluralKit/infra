{ inputs, pkgs, lib, config, ... }:

{
  imports = [
    ../../nixosModules/worker.nix
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

  pkTailscaleIp = "100.100.251.99";
  pkWorkerSubnet = "172.17.1.0/24";

  networking.hostId = "858a0900";
  systemd.network = {
    netdevs."internal" = {
      netdevConfig = { Name = "internal"; Kind = "vlan"; };
      vlanConfig = { Id = 4000; };
    };

    networks."eth0" = {
      matchConfig = { Name = "eth0"; };
      address = [ "116.202.146.157/26" ];
      gateway = [ "116.202.146.129" ];
      vlan = [ "internal" ];
    };

    networks."internal" = {
      matchConfig = { Name = "internal"; };
      address = [ "10.0.1.7/24" ];
      routes = [
        { routeConfig = { Destination = "10.0.0.0/24"; Gateway = "10.0.1.1"; }; }
      ];
    };
  };

  system.stateVersion = "24.04";
}
