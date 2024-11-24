job "app_dashboard" {
	name = "dashboard"
	datacenters = ["dc1"]

	constraint {
		attribute = "${node.class}"
		value = "compute"
	}

	group "dashboard" {
		task "dashboard" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/dashboard:version"
				advertise_ipv6_address = true
			}

			service {
				name = "pluralkit-dashboard"
				address_mode = "driver"
				provider = "consul"
			}
		}
	}
}
