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

  systemd.services.vector = {
    description = "Vector.dev (logs)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "consul.service" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.vector}/bin/vector --config ${pkgs.writeTextFile {
        name = "vector.conf";
        text = ''
          [sources.docker-rust]
          type = "docker_logs"
          include_labels = ["pluralkit_rust=true"]

          [transforms.tf-docker-rust]
          type = "remap"
          inputs = ["docker-rust"]
          source = ".data = parse_json(.message) ?? {}"

          [sinks.opensearch]
          type = "elasticsearch"
          api_version = "v8"
          inputs = ["tf-docker-rust"]
          bulk.index = "pluralkit-rust"
          endpoints = ["http://observability.svc.pluralkit.net:9200"]
        '';
      }}";
      DynamicUser = true;
      Group = "docker";
      Restart = "always";
      StateDirectory = "vector";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    };
    unitConfig = {
      StartLimitIntervalSec = 10;
      StartLimitBurst = 5;
    };
  };

  pkServerChecks = [
    { type = "systemd_service_running"; value = "nomad"; }
    { type = "systemd_service_running"; value = "docker"; }
    { type = "systemd_service_running"; value = "vector"; }
  ];
}
