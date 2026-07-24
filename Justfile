# adapted from https://git.vulpe.systems/vulpe-systems/nix/src/branch/main/Justfile
alias d := deploy
alias h := help
alias u := update

set default-list
set lists
set unstable

# Get help for a just task
help task:
  @just --usage {{ task }}

# Update input(s) for the flake
[arg('input', help="The specific input to update")]
update input="":
  nix flake update {{ input }}

export NIX_SSHOPTS := "-i ~/.ssh/provisioner"

op-default := "build"
# Deploy a flake config to a target.
[arg('target', help="The host to deploy to")]
[arg('operation', pattern='switch|boot|build|test', help="The operation to perform on the host. Must match a nixos-rebuild operation.")]
[arg('user', help="The user to use for deployment.")]
deploy target operation=op-default user="root":
  nh os {{ operation }} . -t \
    --build-host {{ user }}@{{ target }}.prod.pluralkit.net \
    --target-host {{ user }}@{{ target }}.prod.pluralkit.net \
    --hostname {{ target }}
