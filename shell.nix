{
  pkgs-unstable,
  ...
}:
# we use pkgs-unstable here because it's more likely to be updated
pkgs-unstable.mkShellNoCC {
  packages = with pkgs-unstable; [
    just
    nh
    nil
    nixfmt
  ];
}
