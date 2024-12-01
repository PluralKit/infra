{ lib, pkgs, config, ... }:

let
  publicIp = builtins.head (
    lib.strings.split "/" 
      (builtins.head config.systemd.network.networks.eth0.address)
  );
in {
  imports = [ ./nomad-client.nix ];

  # add anycast IPs to lo
	systemd.network.networks.lo.address = [
    "70.34.215.108/32"
    "2a05:f480:2000:2894::/128"
  ];

  services.bird2 = {
    enable = true;
    autoReload = false;
    config = ''
      log syslog all;
      router id ${publicIp};

      protocol device {

      }

      protocol static {
        ipv4;
        route 70.34.215.108/32 via "lo";
      }

      protocol static {
        ipv6;
        route 2a05:f480:2000:2894::/128 via "lo";
      }

      protocol bgp vultr {
        local as 4288000156;
        source address ${publicIp};
        ipv4 {
                import none;
                export all;
        };
        graceful restart on;
        multihop 2;
        neighbor 169.254.169.254 as 64515;
        include "/etc/pluralkit/bgp-password";
      }

      protocol bgp vultr6 {
        local as 4288000156;
        ipv6 {
                import none;
                export all;
        };
        graceful restart on;
        multihop 2;
        neighbor 2001:19f0:ffff::1 as 64515;
        include "/etc/pluralkit/bgp-password";
      }
    '';
    preCheckConfig = ''
      rm bird2.conf
      cp $out bird2.conf
      touch /tmp/empty
      sed -i 's/\/etc\/pluralkit\/bgp-password/\/tmp\/empty/' bird2.conf
    '';
  };

  services.nomad.settings.client.node_class = "edge";

  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 1;

  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 80 443 ];

  systemd.services.caddy.serviceConfig.EnvironmentFile = "/etc/pluralkit/caddy_environ";
  services.caddy = {
    enable = true;
    configFile = ./Caddyfile.edge;
  };
  environment.etc = {
    "caddy/anycast.html".text = ''
      <!DOCTYPE html>
      <head><title>PluralKit HTTP server</title></head>
      <body<p>Hello! This is PluralKit's public HTTP server.
      You are probably looking for <a href="https://pluralkit.me">our website</a>?
      <br>If any content hosted here breaks the <a href="https://pluralkit.me/terms-of-service/">PluralKit Terms of Service</a>,
      or is otherwise illegal, please contact us at <a href="mailto:abuse@pluralkit.me">abuse@pluralkit.me</a>
      with the link to the content and any other relevant information.</p>
      </body>
    '';

    "caddy/stats.html".text = ''
      <!DOCTYPE html>
      <head><title>PluralKit Stats</title>
      <style>* { margin: 0; border: 0; height: 100%; }</style></head>
      <body><iframe src="https://grafana.pluralkit.me/public-dashboards/dc49de1080914e5ea1ef2e261f3b71d4"
      style="width: 100%; height: 100%; display: block;"></iframe></body>
    '';
  };
}
