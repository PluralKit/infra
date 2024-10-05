{ inputs
, self
, ...
}:

let
  mkSystem = hostName: system: { extraSpecialArgs ? {}, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = extraSpecialArgs // {
        inherit inputs;
        _passthru = {
          inherit system hostName;
        };
      };

      modules = [
        ({ _passthru, system, ... }: {
          nixpkgs.hostPlatform = _passthru.system;
          networking.hostName = _passthru.hostName;
        })

        self.nixosModules.base
        ./${hostName}
      ];
    };

in
{
  flake.nixosConfigurations = {
    db2 = mkSystem "db2" "x86_64-linux" {};
    compute03 = mkSystem "compute03" "x86_64-linux" {};
    vps = mkSystem "vps" "x86_64-linux" {};
    manage-tmp = mkSystem "manage-tmp" "x86_64-linux" {};
    manage-tmp2 = mkSystem "manage-tmp2" "x86_64-linux" {};
  };
}
