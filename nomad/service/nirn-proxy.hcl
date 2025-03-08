job "service_nirn-proxy" {
  datacenters = ["dc1"]

  group "nirn" {
    constraint {
      attribute = "${node.class}"
      value = "compute"
    }

    task "nirn" {
      driver = "docker"

      config {
        image = "ghcr.io/pluralkit/nirn-proxy:8718412d2f67359fd52ea991260ec372d1d7efa5"
        advertise_ipv6_address = true
        hostname = "nirn"
      }

      env {
        PORT = "8002"
        BIND_IP = "[::]"
        METRICS_PORT = "9002"
      }

      service {
        name = "nirn-proxy"
        address_mode = "driver"
        provider = "consul"
      }

      service {
        name = "metrics"
        address_mode = "driver"
        provider = "consul"
        port = 9002
      }

      resources {
        memory = 1000
      }
    }
  }
}
