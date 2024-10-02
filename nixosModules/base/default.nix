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
    NOMAD_ADDR = "http://hashi.svc.pluralkit.net:4646";
    CONSUL_HTTP_ADDR = "http://hashi.svc.pluralkit.net:8500";
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

  networking.nameservers = if config.pkTailscaleIp == ""
    then [ "1.1.1.1" "1.0.0.1" ] # tailscale has not been set up yet
    else [ "100.100.100.100" ];
}
