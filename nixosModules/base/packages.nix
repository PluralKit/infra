{ pkgs
, pkgs-unstable
, lib
, inputs
, ...
}:

{
  services.caddy.package = (pkgs.callPackage ../../packages/caddy.nix {});

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

    (pkgs.callPackage ../../packages/pluralkit-scripts/default.nix {})
    (pkgs.callPackage ../../packages/server-checks/default.nix {})
  ];
}
