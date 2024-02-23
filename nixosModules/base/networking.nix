{ pkgs
, lib
, inputs
, ...
}:

{
  networking.useDHCP = false;
  networking.usePredictableInterfaceNames = false;
  systemd.network.enable = true;

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose";
  };

  services.resolved = {
    enable = true;
    llmnr = "resolve";
    fallbackDns = [ "1.1.1.1" "1.0.0.1" ];
  };

  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--ssh" ];
  };
}
