{ pkgs, lib, config, inputs, ... }:

let
  pluralkit-status = inputs.pluralkit-status.packages.${pkgs.system};
in
{
	services.caddy = {
		enable = true;
    virtualHosts.":5080".extraConfig = ''
      @authAdmin {
        path /api/v1/admin/*
        not remote_ip 100.83.14.76 fd7a:115c:a1e0:ab12:4843:cd96:6253:e4c 127.0.0.1 ::1
      }
      abort @authAdmin

      handle /api/v1/shards {
        header Clear-Site-Data "cache"
        respond 200
      }
      
      handle /api/* {
        reverse_proxy /api/* localhost:5000
      }

      @index {
        path /
        path index.html
      }

      handle {
        root * ${pluralkit-status.pluralkit-status-frontend}
        route {
          try_files {path} @index
          header @index Cache-Control "public, max-age=0, must-revalidate"
        }
        file_server
      }
    '';
	};

	systemd.services.pluralkit-status-backend = {
    wantedBy = [ "multi-user.target" ];
		after = [ "tailscaled.service" ];
    serviceConfig = {
      ExecStart = ''
        ${pluralkit-status.pluralkit-status-backend}/bin/status
      '';
      EnvironmentFile = "/etc/pluralkit/statuspage.env";
    };
	};

	pkServerChecks = [
		{ type = "systemd_service_running"; value = "pluralkit-status-backend"; }
		{ type = "systemd_service_running"; value = "caddy"; }
	];
}
