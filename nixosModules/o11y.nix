{ pkgs, lib, config, ... }:

let
	mkSimpleService = execStart:
	{
		wantedBy = [ "multi-user.target" ];
		after = [ "tailscaled.service" ];
		serviceConfig.ExecStart = execStart;
	};
in
{
	fileSystems."/srv" = { device = "/dev/sdb"; fsType = "ext4"; };

	services.caddy = {
		enable = true;
		user = "root";
		configFile = pkgs.writeText "Caddyfile" ''
metrics.svc.pluralkit.net:80 {
	reverse_proxy /insert/* {
		to http://localhost:8480
	}
	reverse_proxy /select/* {
		to http://localhost:8481
	}
}

logs.svc.pluralkit.net:80 {
	reverse_proxy /* {
		to http://localhost:9429
	}
}

alerts.svc.pluralkit.net:80 {
	reverse_proxy /* {
		to http://localhost:9093
	}
}
		'';
	};

	systemd.services = {
		vminsert = mkSimpleService (pkgs.writeShellScript "vminsert" ''
			/usr/local/vicky/bin/vminsert \
				-storageNode=o11y-hchil1-054e59e6.vpn.pluralkit.net \
				-storageNode=o11y-hchil1-054e6bd7.vpn.pluralkit.net \
				-storageNode=o11y-hchil1-054e4c90.vpn.pluralkit.net
		'');
		vmselect = mkSimpleService (pkgs.writeShellScript "vmselect" ''
			/usr/local/vicky/bin/vmselect \
				-storageNode=o11y-hchil1-054e59e6.vpn.pluralkit.net \
				-storageNode=o11y-hchil1-054e6bd7.vpn.pluralkit.net \
				-storageNode=o11y-hchil1-054e4c90.vpn.pluralkit.net
		'');
		vmstorage = mkSimpleService "/usr/local/vicky/bin/vmstorage -storageDataPath=/srv/metrics -retentionPeriod=30d";

		vlproxy = mkSimpleService (pkgs.writeShellScript "vlproxy" ''
			/usr/local/vicky/bin/victorialogs \
				-httpListenAddr=:9429 \
				-storageNode=o11y-hchil1-054e59e6.vpn.pluralkit.net:9428 \
				-storageNode=o11y-hchil1-054e6bd7.vpn.pluralkit.net:9428 \
				-storageNode=o11y-hchil1-054e4c90.vpn.pluralkit.net:9428 
		'');
		vlstorage = mkSimpleService "/usr/local/vicky/bin/victorialogs -storageDataPath=/srv/logs -retentionPeriod=30d";

		# vmalert-metrics = {};
		# vmalert-logs = {};
		# alertmanager = {};
	};

	pkServerChecks = [
		{ type = "systemd_service_running"; value = "vminsert"; }
		{ type = "systemd_service_running"; value = "vmselect"; }
		{ type = "systemd_service_running"; value = "vmstorage"; }
		{ type = "systemd_service_running"; value = "vlproxy"; }
		{ type = "systemd_service_running"; value = "vlstorage"; }
		{ type = "systemd_service_running"; value = "caddy"; }
	];
}
