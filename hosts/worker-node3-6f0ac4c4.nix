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
    mdadmConf = "ARRAY /dev/md0 level=raid1 num-devices=2 metadata=1.2 UUID=dacd0392:d87d3fbb:7e1d960a:70e313f5 devices=/dev/nvme0n1p2,/dev/nvme1n1p2";
  };
  systemd.services."mdmonitor".serviceConfig = {
    ExecStart = [
      ""
      "${pkgs.mdadm}/sbin/mdadm --monitor --scan --syslog"
    ];
  };

  environment.etc.crypttab = {
    mode = "0600";
    text = ''
      # <volume-name> <encrypted-device> [key-file] [options]
      appdata_storage UUID=0ff2ac19-8118-45cf-8690-dfcd3f3e3c40 /etc/pluralkit/appdata.key
    '';
  };

  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXROOT";
      fsType = "ext4";
    };
  fileSystems."/boot" = 
    { device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
    };
  fileSystems."/mnt/appdata" =
    { device = "/dev/disk/by-label/appdata";
      fsType = "ext4";
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

        address = [ "192.168.20.12/24" ];
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
        
        address = [ "91.208.228.71/28" "2403:b4c0:5b07:3::1/48" ];
        routes = [
          {
            Gateway = "91.208.228.65";
            Metric = 100;
          }
          {
            Gateway = "2403:b4c0:5b07::1";
            Metric = 100;
          }
        ];
      };
    };
  };
  networking.firewall.trustedInterfaces = [ "bond0" ];

  pkTailscaleIp = "100.68.216.79";
  system.stateVersion = "25.05";
  
  services.pk-k3s.bridgeSubnet = "10.20.103.0/24";
}
