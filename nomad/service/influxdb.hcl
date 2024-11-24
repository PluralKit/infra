job "service_influxdb" {
  datacenters = ["dc1"]

  group "influxdb" {
    volume "influx-data" {
      type            = "csi"
      source          = "influx-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "influxdb" {
      driver = "docker"

      config {
        image = ""
        advertise_ipv6_address = true
      }

      template {
        data = <<EOF
          create database pluralkit;
          create retention policy dont_fill_up_my_disk on pluralkit duration 4w replication 1 default;
        EOF
        destination = "/docker-entrypoint-initdb.d/influxdb-init.iql"
      }

      volume_mount {
        volume = "influxdb-data"
        destination = "/var/lib/influxdb"
      }

			service {
				name = "influxdb"
				address_mode = "driver"
				provider = "consul"
			}
    }
  }
}
