job "dashboard" {
	name = "dashboard"
	datacenters = ["dc1"]

	constraint {
		attribute = "${attr.unique.hostname}"
		value = "ubuntu-4gb-fsn1-1"
	}

	group "dashboard" {
		network {
			port "port" {
				static = 8080
				to = 8080
				host_network = "6pn"
			}
		}

		task "dashboard" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/dashboard:version"
				ports = ["port"]
			}
		}
	}
}