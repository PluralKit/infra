{ inputs, pkgs, lib, modulesPath, ... }:

{
	imports = [
		../../nixosModules/hashi.nix
		(modulesPath + "/profiles/qemu-guest.nix")
	];

	boot.loader.grub.device = "/dev/sda";
	boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
	boot.initrd.kernelModules = [ "nvme" ];
	fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

	networking.hostId = "d0069ff0";
	systemd.network.networks."eth0" = {
		matchConfig = { Name = "eth0"; };
		address = [ "162.55.174.253/32" "2a01:4f8:1c17:f925::1/64" ];
		gateway = [ "172.31.1.1" "fe80::1" ];
		routes = [
			{ routeConfig = { Destination = "172.31.1.1/32"; Scope = "link"; }; }
		];
	};

  pkTailscaleIp = "100.77.37.109";

  services.caddy = {
    enable = true;
    configFile = pkgs.writeText "Caddyfile" ''
{
        default_bind 162.55.174.253 [2a01:4f8:1c17:f925::1]
}

http://pluralkit.me {
}

api.pluralkit.me {
        reverse_proxy /* {
                to http://pluralkit-api.service.consul:5000
                header_up X-PluralKit-Client-IP {remote_host}
                header_up -x-pluralkit-systemid
        }
}

dash.pluralkit.me {
        reverse_proxy /* {
                to http://pluralkit-dashboard.service.consul:8080
        }
}

gt.pluralkit.me {
        reverse_proxy /* {
                to http://100.100.251.99:8000
        }
}

grafana.pluralkit.me {
        reverse_proxy /* {
                to http://100.83.67.99:3000
                header_down -X-Frame-Options
                header_down +Content-Security-Policy "frame-ancestors stats.pluralkit.me"
        }
}

stats.pluralkit.me {
        file_server / {
                root /etc/caddy
                index stats.html
        }
}
    '';
  };
  environment.etc."caddy/stats.html".text = ''
<!DOCTYPE html>
<head><title>PluralKit Stats</title>
<style>* { margin: 0; border: 0; height: 100%; }</style></head>
<body><iframe
  src="https://grafana.pluralkit.me/public-dashboards/dc49de1080914e5ea1ef2e261f3b71d4"
  style="width: 100%; height: 100%; display: block;"></iframe></body>
  '';

  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 80 443 ];

	system.stateVersion = "24.04";
}
