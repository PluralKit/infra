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

  networking.usePredictableInterfaceNames = false;
  systemd.network = {
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
        };
        bondConfig = {
          Mode = "active-backup";
          TransmitHashPolicy = "layer3+4";
        };
      };
      "20-vlan10" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan10";
        };
        vlanConfig.Id = 10;
      };
    };

    networks = {
      "30-eth0" = {
        matchConfig.Name = "eth0";
        networkConfig.Bond = "bond0";
      };
      "30-eth1" = {
        matchConfig.Name = "eth1";
        networkConfig.Bond = "bond0";
      };
      "40-bond0" = {
        matchConfig.Name = "bond0";
        vlan = [
          "vlan10"
        ];

        address = [ "192.168.20.11/24" ];
        routes = [
          {
            Gateway = "192.168.20.254";
            Metric = 200;
          }
        ];

        networkConfig.LinkLocalAddressing = "no";
        linkConfig.RequiredForOnline = "carrier";
      };
      "50-vlan10" = {
        matchConfig.Name = "vlan10";
        
        address = [ "91.208.228.70/28" ];
        routes = [
          {
            Gateway = "91.208.228.65";
            Metric = 100;
          }
        ];
      };
    };
  };
  networking.firewall.trustedInterfaces = [ "bond0" ];

  pkTailscaleIp = "100.93.93.55";
  system.stateVersion = "25.05";
}