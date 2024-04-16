{ pkgs
, lib
, ...
}:

{
  networking.firewall.interfaces."internal".allowedTCPPorts = [ 6379 ];
  services.redis.servers."pluralkit" = {
    enable = true;
    bind = "127.0.0.1 10.0.1.6";
    port = 6379;
    openFirewall = lib.mkForce false;
    settings = {
      protected-mode = false;
      io-threads = 8;
      tcp-backlog = 511;
    };
  };
}
