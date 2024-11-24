{ pkgs, ... }:

pkgs.buildGoModule rec {
  name = "server-checks";
  pname = "server-checks";
  vendorHash = "sha256-AosTmlP4n+yIfd/fjz/ngfYzRtqZ+E0WEXA3yY7Xowg=";
  src = ./.;
  proxyVendor = true;
}
