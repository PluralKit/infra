{ inputs
, pkgs
, ...
}:

{
  imports = [
    ./hw.nix
  ];

  networking.hostId = "09a9f4ac";
  systemd.network.networks."eth0" = {
    matchConfig = { Name = "eth0"; };
    address = [ "148.251.178.57/26" ];
    gateway = [ "148.251.178.1" ];
  };

  system.stateVersion = "23.11";
}
