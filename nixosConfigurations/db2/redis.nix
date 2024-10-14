{ pkgs
, lib
, config
, ...
}:

{
  services.redis.servers."pluralkit" = {
    enable = true;
    bind = "127.0.0.1 ${config.pkTailscaleIp}";
    port = 6379;
    openFirewall = lib.mkForce false;
    settings = {
      protected-mode = false;
      io-threads = 8;
      tcp-backlog = 511;
    };
  };
}
