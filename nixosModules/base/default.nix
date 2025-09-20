{ pkgs
, config
, lib
, inputs
, ...
}:

{
  imports = [
    ./pkOptions.nix
    ./users.nix
    ./packages.nix
    ./networking.nix
    ./metrics.nix
    ./logs.nix
    ../../packages/server-checks/configuration.nix
  ];

  time.timeZone = "Etc/UTC";

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };

    registry = {
      nixpkgs.flake = inputs.nixpkgs;
    };
  };

  security.sudo = {
    wheelNeedsPassword = lib.mkForce false;
    execWheelOnly = lib.mkForce true;
  };

  services.openssh = {
    enable = true;
    settings = {
      UseDns = false;
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AllowGroups = [ "wheel" ];
    };
  };

  systemd.services.tailscale-ready = let
    check-interface-ready = pkgs.callPackage ../../packages/check-interface-ready {};
  in {
    wantedBy = [ "multi-user.target" ];
		after = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "2min";
      ExecStart = [
        "+${check-interface-ready}/bin/check-interface-ready tailscale0"
      ];
    };
  };

  networking.nameservers = if config.pkTailscaleIp == ""
    then [ "1.1.1.1" "1.0.0.1" ] # tailscale has not been set up yet
    else [ "100.100.100.100" ];

  # global checks
  pkServerChecks = [
    { type = "systemd_no_failing_services"; }
    { type = "systemd_service_running"; value = "tailscaled"; }
    { type = "systemd_service_running"; value = "sshd"; }
  ];
}
