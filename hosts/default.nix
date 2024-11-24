{ inputs
, self
, lib
, ...
}:

let
  mkSystem = hostName: system: { extraSpecialArgs ? {}, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = let
        pkgs-unstable = import inputs.nixpkgs-unstable {
          config.allowUnfree = true;
          localSystem = { inherit system; };
        };
      in extraSpecialArgs // {
        inherit inputs;
        inherit pkgs-unstable;
        _passthru = {
          inherit system hostName;
        };
      };

      modules = [
        ({ _passthru, system, ... }: {
          nixpkgs.hostPlatform = _passthru.system;
          networking.hostName = _passthru.hostName;

          networking.hostId = let
            splitHostname = (lib.strings.splitString "-" _passthru.hostName);
          in (builtins.elemAt splitHostname ((builtins.length splitHostname) - 1));
        })

        self.nixosModules.base
        ./${hostName}.nix
      ];
    };

in
{
  flake.nixosConfigurations = (lib.genAttrs
    (map
      (x: lib.strings.removeSuffix ".nix" x)
      (lib.lists.remove "default.nix" (builtins.attrNames (builtins.readDir ./.)))
    )
    (name: mkSystem name "x86_64-linux" {}));
}
