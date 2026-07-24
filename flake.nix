{
  outputs = { flake-parts, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      imports = [
        ./hosts
        ./nixosModules
      ];

      flake.overlays.default = import ./packages/overlay.nix { inherit inputs; };
      perSystem = { pkgs, config, system, ... }: {
        packages = import ./packages { inherit inputs; } pkgs;
        devShells.default =
          let
            pkgs-unstable = import inputs.nixpkgs-unstable {
              inherit system;
            };
          in
          pkgs.callPackage ./shell.nix { inherit config pkgs-unstable; };
      };
    };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # yeah i hate this
    # but k3s and postgres are the hardest packages to update, they tend to break things
    # pin them so we can somewhat safely update other packages without bringing PK down
    nixpkgs-postgres.url = "github:nixos/nixpkgs/09eb77e94fa25202af8f3e81ddc7353d9970ac1b";
    nixpkgs-k3s.url = "github:nixos/nixpkgs/ffbc9f8cbaacfb331b6017d5a5abb21a492c9a38";

    flake-utils.url = "github:numtide/flake-utils";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };
}
