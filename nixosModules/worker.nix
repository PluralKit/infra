{ inputs, pkgs, lib, config, ... }:

let
  pkWorkerSubnet = let
    pt1 = builtins.substring 0 4 config.networking.hostId;
    pt2 = builtins.substring 4 8 config.networking.hostId;
  in "fdef:${pt1}:${pt2}::/80";
in {
  imports = [ ./nomad-client.nix ];

  virtualisation.docker.daemon.settings = {
    experimental = true;
    ip6tables = true;
    ipv6 = true;
    fixed-cidr-v6 = pkWorkerSubnet;
  };

  services.tailscale.extraSetFlags = [ "--advertise-routes=${pkWorkerSubnet}" ];

  services.nomad.settings.client.node_class = "compute";

  pkLogTargets = [
    ''
      [sources.docker]
      type = "docker_logs"

      [sinks.opensearch-docker]
      type = "elasticsearch"
      api_version = "v8"
      inputs = ["docker"]
      bulk.index = "docker"
      endpoints = ["http://es.svc.pluralkit.net"]

      [sources.docker-rust]
      type = "docker_logs"
      include_labels = ["pluralkit_rust=true"]

      [transforms.tf-docker-rust]
      type = "remap"
      inputs = ["docker-rust"]
      source = ".data = parse_json(.message) ?? {}"

      [sinks.opensearch-rust-new]
      type = "elasticsearch"
      api_version = "v8"
      inputs = ["tf-docker-rust"]
      bulk.index = "pluralkit-rust"
      endpoints = ["http://es.svc.pluralkit.net"]
    ''
  ];

  pkServerChecks = [
    { type = "systemd_service_running"; value = "nomad"; }
    { type = "systemd_service_running"; value = "docker"; }
    { type = "systemd_service_running"; value = "vector"; }
  ];
}
