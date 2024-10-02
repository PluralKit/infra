{ lib, ... }: 

{
	options = {
		pkTailscaleIp = lib.mkOption {
			default = "";
		};
	};
}
