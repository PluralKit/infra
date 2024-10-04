{ pkgs, ... }:

pkgs.buildGoModule rec {
  name = "server-checks";
  pname = "server-checks";
  vendorHash = "sha256-CvkaOXCPm56DgjVLlwFssI5QqoyzgGx/WGYJzJwE4U8=";
  src = ./.;
  proxyVendor = true;
}
