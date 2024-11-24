job "service_grafana" {
  datacenters = ["dc1"]

  group "grafana" {
    volume "grafana-data" {
      type            = "csi"
      source          = "grafana-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    network {
      port "port" {}
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:11.3.0-security-01"
        advertise_ipv6_address = true
      }

      volume_mount {
        volume = "grafana-data"
        destination = "/var/lib/grafana"
      }

			service {
				name = "grafana"
				address_mode = "driver"
				provider = "consul"
				port = "port"
			}
    }
  }
}
