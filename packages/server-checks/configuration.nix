{ pkgs, lib, config, ... }:

{
	options = {
		pkServerChecks = lib.mkOption {
			type = with lib.types; listOf anything;
			default = [];
		};
	};

	config = let 
		package = (pkgs.callPackage ../../packages/server-checks/default.nix {});
	in {
		environment.shellInit = ''
			${package}/bin/server-checks
		'';
		environment.etc."/server-checks/checks.json".text = builtins.toJSON config.pkServerChecks;
		systemd.services.pluralkit-server-checks = {
			description = "PluralKit server monitoring daemon";
			wantedBy = [ "multi-user.target" ];
			after = [ "network.target" ];

			serviceConfig = {
				ExecStart = "${package}/bin/server-checks agent";
				User = "root";
			};
		};
		networking.firewall.interfaces.eth0.allowedTCPPorts = [ 19999 ];
	};
}
