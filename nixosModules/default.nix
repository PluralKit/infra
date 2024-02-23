{ inputs, ... }:

with builtins;
with inputs.nixpkgs.lib;

{
  flake.nixosModules =
    (mapAttrs'
      (name: _: nameValuePair name (import (./. + "/${name}")))
      (filterAttrs
        (name: ty: (ty == "directory") && (pathExists (./. + "/${name}/default.nix")))
        (readDir ./.)));
}
