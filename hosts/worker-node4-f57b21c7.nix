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
      appdata_storage UUID=db474b41-ed6d-468a-975a-20323f6694fc /etc/pluralkit/appdata.key
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

  pluralkit.bond-setup = {
    enable = true;

    bondAddresses = [ "192.168.20.13/24" ];
    bondGateway = "192.168.20.254";

    vlans = {
      "public" = {
        id = 10;
        addresses = [ "91.208.228.72/28" "2403:b4c0:5b07:4::1/48" ];
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

  pkTailscaleIp = "100.68.206.85";
  system.stateVersion = "25.05";

  services.pk-k3s.bridgeSubnet = "10.20.104.0/24";
}
