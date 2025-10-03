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

  boot.swraid = {
    enable = true;
    mdadmConf = "ARRAY /dev/md0 level=raid1 num-devices=2 metadata=1.2 UUID=496faca7:e878dd44:ee4eb9a8:f8d72e3f devices=/dev/nvme0n1p2,/dev/nvme1n1p2";
  };
  systemd.services."mdmonitor".environment = {
    MDADM_MONITOR_ARGS = "--scan --syslog";
  };

  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXROOT";
      fsType = "ext4";
    };
  fileSystems."/boot" = 
    { device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
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

        address = [ "192.168.20.13/24" ];
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
        
        address = [ "91.208.228.72/28" ];
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

  pkTailscaleIp = "100.68.206.85";
  system.stateVersion = "25.05";
}