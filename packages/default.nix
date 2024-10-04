toplevel @ { inputs, ... }: pkgs:

with pkgs.lib;
let
  system = pkgs.stdenv.hostPlatform.system or pkgs.system;

in
{
  pluralkit-scripts = pkgs.callPackage ./pluralkit-scripts {};
  nirn-proxy = pkgs.callPackage ./nirn-proxy.nix {};
  server-checks = pkgs.callPackage ./server-checks {};
}
