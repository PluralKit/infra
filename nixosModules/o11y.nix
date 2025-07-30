{ pkgs, lib, config, ... }:

let
	mkSimpleService = execStart:
	{
		wantedBy = [ "multi-user.target" ];
		after = [ "tailscaled.service" ];
		serviceConfig.ExecStart = execStart;
	};

	observabilityHosts = [
		"o11y-hchil1-054e59e6"
		"o11y-hchil1-054e6bd7"
		"o11y-hchil1-054e4c90"
	];
	storageArgsVM = builtins.concatStringsSep " " (builtins.map (host: "-storageNode=${host}.vpn.pluralkit.net") observabilityHosts);
	storageArgsVL = builtins.concatStringsSep " " (builtins.map (host: "-storageNode=${host}.vpn.pluralkit.net:9428") observabilityHosts);
	notifierArgs = builtins.concatStringsSep " " (builtins.map (host: "-notifier.url=http://${host}.vpn.pluralkit.net:9093") observabilityHosts);
in
{
	fileSystems."/srv" = { device = "/dev/sdb"; fsType = "ext4"; };

	services.caddy = {
		enable = true;
		user = "root";
		configFile = ../observability/configs/Caddyfile;
	};

	systemd.services = {
		vminsert = mkSimpleService (pkgs.writeShellScript "vminsert" ''
			/usr/local/vicky/bin/vminsert \
				${storageArgsVM}
		'');
		vmselect = mkSimpleService (pkgs.writeShellScript "vmselect" ''
			/usr/local/vicky/bin/vmselect \
				${storageArgsVM}
		'');
		vmstorage = mkSimpleService "/usr/local/vicky/bin/vmstorage -storageDataPath=/srv/metrics -retentionPeriod=30d";

		vlproxy = mkSimpleService (pkgs.writeShellScript "vlproxy" ''
			/usr/local/vicky/bin/victorialogs \
				-httpListenAddr=:9429 \
				${storageArgsVL}
		'');
		vlstorage = mkSimpleService "/usr/local/vicky/bin/victorialogs -storageDataPath=/srv/logs -retentionPeriod=30d";

		vmalert-metrics = mkSimpleService (pkgs.writeShellScript "vmalert-metrics" ''
			/usr/local/vicky/bin/vmalert \
				-rule=${../observability/configs/vmalert-metrics.yml} \
				-datasource.url=http://metrics.svc.pluralkit.net:80/select/0/prometheus/ \
				-remoteWrite.url=http://metrics.svc.pluralkit.net:80/insert/0/prometheus/ \
				-remoteRead.url=http://metrics.svc.pluralkit.net:80/select/0/prometheus/ \
				${notifierArgs}
		'');
		vmalert-logs = mkSimpleService (pkgs.writeShellScript "vmalert-logs" ''
			/usr/local/vicky/bin/vmalert \
				-rule=${../observability/configs/vmalert-logs.yml}  \
				-httpListenAddr=:8881 \
				-rule.defaultRuleType=vlogs \
				-datasource.url=http://logs.svc.pluralkit.net:80/ \
				-remoteWrite.url=http://metrics.svc.pluralkit.net:80/insert/0/prometheus/ \
				-remoteRead.url=http://metrics.svc.pluralkit.net:80/select/0/prometheus/ \
				${notifierArgs}
		'');

		alertmanager = mkSimpleService (pkgs.writeShellScript "alertmanager" ''
			/usr/bin/alertmanager \
				--config.file=${../observability/configs/alertmanager.yml} \
				--storage.path=/srv/alertmanager \
				--cluster.listen-address=${config.pkTailscaleIp}:9094 \
				--cluster.advertise-address=${config.pkTailscaleIp}:9094 \
				--cluster.peer=alerts.svc.pluralkit.net:9094 \
		'');
	};

	pkServerChecks = [
		{ type = "systemd_service_running"; value = "vminsert"; }
		{ type = "systemd_service_running"; value = "vmselect"; }
		{ type = "systemd_service_running"; value = "vmstorage"; }
		{ type = "systemd_service_running"; value = "vlproxy"; }
		{ type = "systemd_service_running"; value = "vlstorage"; }
		{ type = "systemd_service_running"; value = "vmalert-metrics"; }
		{ type = "systemd_service_running"; value = "vmalert-logs"; }
		{ type = "systemd_service_running"; value = "alertmanager"; }
		{ type = "systemd_service_running"; value = "caddy"; }
	];
}
