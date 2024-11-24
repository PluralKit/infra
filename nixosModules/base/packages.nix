{ pkgs
, pkgs-unstable
, lib
, inputs
, ...
}:

{
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nomad" "consul" "vault-bin"
  ];

  services.nomad.package = pkgs-unstable.pkgs.nomad;

  environment.systemPackages = with pkgs; [
    tmux
    htop
    git
    jq

    nftables
    tcpdump
    dig

    # editors
    vim
    nano
    mle
    helix

    # this is here for the client tools
    postgresql_15

    (pkgs.callPackage ../../packages/pluralkit-scripts/default.nix {})
    (pkgs.callPackage ../../packages/server-checks/default.nix {})
  ];
}
