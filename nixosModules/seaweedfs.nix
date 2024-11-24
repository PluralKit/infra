{ inputs, pkgs, lib, config, ... }:

# CSI (Nomad storage) with SeaweedFS
{
	options = {
		seaweedMaster = lib.mkOption {
			default = false;
		};
		seaweedStorageSize = lib.mkOption {
			default = 0;
		};
	};

	config = {
		environment.systemPackages = [ pkgs.seaweedfs ];

		environment.etc."seaweedfs/filer.toml" = {
			enable = config.seaweedMaster != false;
			text = ''
				[filer.options]
				recursive_delete = false

				[leveldb2]
				enabled = true
				dir = "/opt/seaweedfs-filer"
			'';
		};

		systemd.services = {
			seaweedfs-master = {
				enable = config.seaweedMaster != false;
				wantedBy = [ "multi-user.target" ];
				after = [ "tailscaled.service" ];
				requires = [ "tailscaled.service" ];
				serviceConfig = {
					ExecStart = "${pkgs.seaweedfs}/bin/weed master -mdir=/opt/seaweedfs-master -ip=${config.pkTailscaleIp}";
					Restart = "always";
				};
			};

			seaweedfs-filer = {
				enable = config.seaweedMaster != false;
				wantedBy = [ "multi-user.target" ];
				after = [ "tailscaled.service" ];
				requires = [ "tailscaled.service" ];
				serviceConfig = {
					ExecStart = "${pkgs.seaweedfs}/bin/weed filer -ip=${config.pkTailscaleIp} -master=hashi.svc.pluralkit.net:9333";
					Restart = "always";
				};
			};

			seaweedfs-volume = {
				enable = config.seaweedStorageSize > 0;
				wantedBy = [ "multi-user.target" ];
				after = [ "tailscaled.service" ];
				requires = [ "tailscaled.service" ];
				serviceConfig = {
					ExecStart = "${pkgs.seaweedfs}/bin/weed volume --max=${toString config.seaweedStorageSize} -mserver=hashi.svc.pluralkit.net:9333 -ip=${config.pkTailscaleIp} -dir=/mnt/csi";
					Restart = "always";
				};
			};
		};

		pkServerChecks = if config.seaweedStorageSize > 0 then [
	    { type = "systemd_service_running"; value = "seaweedfs-volume"; }
		] else if config.seaweedMaster == true then [
	    { type = "systemd_service_running"; value = "seaweedfs-master"; }
	    { type = "systemd_service_running"; value = "seaweedfs-filer"; }
		] else [];
	};
}
