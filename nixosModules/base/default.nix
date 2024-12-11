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

  environment.variables = {
    NOMAD_ADDR = "http://${config.pkTailscaleIp}:4646";
    CONSUL_HTTP_ADDR = "${config.pkTailscaleIp}:8500";
    VAULT_ADDR = "http://hashi.svc.pluralkit.net:8200";
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

  systemd.services.consul = let
    check-interface-ready = pkgs.callPackage ../../packages/check-interface-ready {};
  in {
    serviceConfig = {
      AmbientCapabilities = "cap_net_bind_service";
      Restart = lib.mkForce "always";
      RestartMode = "quick";
      RestartSec = 5;
      ExecStartPre = [
        "+${check-interface-ready}/bin/check-interface-ready tailscale0"
      ];
    };
    unitConfig.StartLimitIntervalSec = 0;
  };
  services.consul = {
    enable = config.pkTailscaleIp != "";
    extraConfig = {
      bind_addr = "${config.pkTailscaleIp}";
      addresses.http = "${config.pkTailscaleIp}";
      addresses.dns = "169.254.254.169";
      ports.dns = 53;
      retry_join = ["hashi.svc.pluralkit.net"]; # todo: is this correct for a client?
    };
  };

  networking.nameservers = if config.pkTailscaleIp == ""
    then [ "1.1.1.1" "1.0.0.1" ] # tailscale has not been set up yet
    else [ "100.100.100.100" ];

  # global checks
  pkServerChecks = [
    { type = "systemd_no_failing_services"; }
    { type = "systemd_service_running"; value = "tailscaled"; }
    { type = "systemd_service_running"; value = "consul"; }
    { type = "systemd_service_running"; value = "sshd"; }
  ];
}
