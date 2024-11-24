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

  systemd.network = {
    wait-online.enable = false;

    networks."lo" = {
      matchConfig = { Name = "lo"; };
      address = [ "127.0.0.1/8" "[::1]/128" "169.254.169.254" ];
    };
  };

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--accept-routes" ];
  };
}
