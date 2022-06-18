job "extras" {
  name = "extras"
  datacenters = ["dc1"]

  vault {
    policies = ["read-kv"]
  }

  group "caddy" {
    volume "config" {
      type = "host"
      read_only = true
      source = "caddy_config"
    }
    volume "data" {
      type = "host"
      read_only = false
      source = "caddy_data"
    }

    network {
      port "http" {
        static = 80
        to = 80
      }
      port "https" {
        static = 443
        to = 443
      }
    }

    task "caddy" {
      driver = "docker"
      config {
        image = "caddy"
        ports = ["http", "https"]
      }

      volume_mount {
        volume = "config"
        destination = "/etc/caddy"
      }

      volume_mount {
        volume = "data"
        destination = "/data/caddy"
      }
    }
  }
}