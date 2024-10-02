job "avatars" {
	name = "avatars"
	datacenters = ["dc1"]

	constraint {
		attribute = "${attr.unique.hostname}"
		value = "compute03"
	}

	vault {
		policies = ["read-kv"]
	}

	group "avatars" {
		count = 2
		network {
			port "port" {
				to = 3000
			}
		}

		task "avatars" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/avatars:version"
				ports = ["port"]
			}

			template {
				data = <<EOH
					{{ with secret "kv/pluralkit" }}
					PK_AVATAR__DB = "postgres://pluralkit:{{ .Data.databasePassword }}@10.0.1.6:5432/pluralkit"
					PK_AVATAR__BASE_URL = "https://cdn.pluralkit.me/"
					PK_AVATAR__S3__BUCKET = "pluralkit-avatars"
					PK_AVATAR__S3__ENDPOINT = "https://s3.eu-central-003.backblazeb2.com"
					PK_AVATAR__S3__APPLICATION_ID = "0031de9bd0a26160000000005"
					PK_AVATAR__S3__APPLICATION_KEY = "{{ .Data.avatarsB2ApplicationKey }}"
					{{ end }}
				EOH

				destination = "local/env"
				env = true
			}

			service {
				name = "pluralkit-avatars"
				address_mode = "driver"
				port = "port"
				provider = "consul"
			}
		}
	}
}
