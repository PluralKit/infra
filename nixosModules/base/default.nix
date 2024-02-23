{ pkgs
, lib
, inputs
, ...
}:

{
  imports = [
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
}
