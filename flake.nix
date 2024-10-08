{
  outputs = { flake-parts, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      imports = [
        ./nixosConfigurations
        ./nixosModules
      ];

      flake.overlays.default = import ./packages/overlay.nix { inherit inputs; };
      perSystem = { pkgs, ... }: {
        packages = import ./packages { inherit inputs; } pkgs;
      };
    };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    flake-utils.url = "github:numtide/flake-utils";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };
}
