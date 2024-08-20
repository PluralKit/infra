job "dashboard" {
	name = "dashboard"
	datacenters = ["dc1"]

	constraint {
		attribute = "${attr.unique.hostname}"
		value = "compute03"
	}

	group "dashboard" {
		network {
			port "port" {
				to = 8080
			}
		}

		task "dashboard" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/dashboard:version"
				ports = ["port"]
			}

			service {
				name = "pluralkit-dashboard"
				address_mode = "driver"
				port = "port"
				provider = "consul"
			}
		}
	}
}
