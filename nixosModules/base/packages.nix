{ pkgs
, lib
, inputs
, ...
}:

{
  environment.systemPackages = with pkgs; [
    tmux
    htop
    git

    # editors
    vim
    nano
    mle

    # this is here for the client tools
    postgresql_15
  ];
}
