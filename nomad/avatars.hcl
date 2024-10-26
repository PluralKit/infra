job "avatars" {
	name = "avatars"
	datacenters = ["dc1"]

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
				pluralkit__db__db_password={{ .Data.databasePassword }}

				pluralkit__avatars__s3__application_key={{ .Data.avatarsB2ApplicationKey }}
				{{ end }}

				EOH

				destination = "local/env"
				env = true
			}

			env {
				RUST_LOG="info"
				pluralkit__json_log=true

				pluralkit__db__data_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5432/pluralkit"
				pluralkit__avatars__cdn_url="https://cdn.pluralkit.me/"
				pluralkit__avatars__s3__bucket="pluralkit-avatars"
				pluralkit__avatars__s3__endpoint="https://s3.eu-central-003.backblazeb2.com"
				pluralkit__avatars__s3__application_id="0031de9bd0a26160000000005"

				pluralkit__db__data_redis_addr=1
			}

			service {
				name = "pluralkit-avatars"
				address_mode = "driver"
				port = "port"
				provider = "consul"
			}
		}
	}

	group "avatar_cleanup" {
		count = 4
		task "avatar_cleanup" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/avatars:image"
				command = "/bin/avatar_cleanup"
			}

			template {
				data = <<EOH
				{{ with secret "kv/pluralkit" }}
				pluralkit__db__db_password={{ .Data.databasePassword }}

				pluralkit__avatars__s3__application_key={{ .Data.avatarsB2ApplicationKey }}
				pluralkit__avatars__cloudflare_token={{ .Data.cloudflareCdnPurgeToken }}
				{{ end }}

				EOH

				destination = "local/env"
				env = true
			}

			env {
				RUST_LOG="info"
				pluralkit__json_log=true

				pluralkit__db__data_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5432/pluralkit"
				pluralkit__avatars__cdn_url="https://cdn.pluralkit.me/"
				pluralkit__avatars__s3__bucket="pluralkit-avatars"
				pluralkit__avatars__s3__endpoint="https://s3.eu-central-003.backblazeb2.com"
				pluralkit__avatars__s3__application_id="0031de9bd0a26160000000005"
				pluralkit__avatars__cloudflare_zone_id="89cf81906a060c313d7178e27e430730"

				pluralkit__db__data_redis_addr=1
			}
		}
	}
}
