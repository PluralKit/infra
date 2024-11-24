job "service_postgres-stats" {
  datacenters = ["dc1"]

  group "postgres" {
    volume "pg-data" {
      type            = "csi"
      source          = "stats-pg-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "postgres-stats" {
      driver = "docker"

      config {
        image = "timescale/timescaledb:latest-pg14"
        advertise_ipv6_address = true
      }

      volume_mount {
        volume = "pg-data"
        destination = "/var/lib/postgresql/data"
      }

			service {
				name = "postgres-stats"
				address_mode = "driver"
				provider = "consul"
			}
    }
  }
}
