job "app_jobs" {
	datacenters = ["dc1"]

	vault {
		policies = ["read-kv"]
	}

  constraint {
    attribute = "${node.class}"
    value = "compute"
  }

	group "avatar_cleanup" {
		count = 0
		task "avatar_cleanup" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/avatars:image"
				command = "/bin/avatar_cleanup"
				labels = { pluralkit_rust = "true" }
			}

			template {
				data = <<EOH
				{{ with secret "kv/pluralkit" }}
				pluralkit__db__db_password={{ .Data.databasePassword }}
				pluralkit__avatars__s3__application_key={{ .Data.avatarsB2ApplicationKey }}
				pluralkit__avatars__cloudflare_token={{ .Data.cloudflareCdnPurgeToken }}
				pluralkit__sentry_url={{ .Data.avatarsSentryUrl }}
				{{ end }}

				EOH

				destination = "local/env"
				env = true
			}

			env {
				RUST_LOG="info"
				pluralkit__json_log=true

				pluralkit__db__data_db_uri="postgresql://pluralkit@database-hrhel1-251b75a5.vpn.pluralkit.net:5432/pluralkit"
				pluralkit__avatars__cdn_url="https://cdn.pluralkit.me/"
				pluralkit__avatars__s3__bucket="pluralkit-avatars"
				pluralkit__avatars__s3__endpoint="https://s3.eu-central-003.backblazeb2.com"
				pluralkit__avatars__s3__application_id="0031de9bd0a26160000000005"
				pluralkit__avatars__cloudflare_zone_id="89cf81906a060c313d7178e27e430730"

				pluralkit__db__data_redis_addr=1
			}
		}
	}

	group "gdpr_worker" {
		count = 0
		task "gdpr_worker" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/gdpr_worker:image"
				labels = { pluralkit_rust = "true" }
			}

			template {
				data = <<EOH
				{{ with secret "kv/pluralkit" }}
        pluralkit__db__db_password={{ .Data.databasePassword }}
	      pluralkit__discord__bot_token={{ .Data.discordToken }}
	      pluralkit__sentry_url={{ .Data.scheduledTasksSentryUrl }}
				{{ end }}

				EOH

				destination = "local/env"
				env = true
			}

			env {
				RUST_LOG="debug"
				pluralkit__json_log=true

				pluralkit__db__messages_db_uri="postgresql://pluralkit@database-hrhel1-251b75a5.vpn.pluralkit.net:5434/messages"
        pluralkit__discord__api_base_url="nirn-proxy.service.consul:8002"

				pluralkit__db__data_db_uri=1
				pluralkit__discord__client_id=1
				pluralkit__discord__client_secret=1
				pluralkit__discord__max_concurrency=1
				pluralkit__db__data_redis_addr=1
			}
		}
	}

	group "scheduled_tasks" {
		task "scheduled_tasks" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/scheduled_tasks:image"
				advertise_ipv6_address = true
				labels = { pluralkit_rust = "true" }
			}

			template {
				data = <<EOD
					{{ with secret "kv/pluralkit" }}
					pluralkit__db__db_password={{ .Data.databasePassword }}
	        pluralkit__discord__bot_token={{ .Data.discordToken }}
	        pluralkit__sentry_url={{ .Data.scheduledTasksSentryUrl }}
					{{ end }}
				EOD
				destination = "local/secret.env"
				env = true
			}

			env {
				RUST_LOG="info"
				pluralkit__json_log=true

				pluralkit__run_metrics_server=true
				pluralkit__scheduled_tasks__set_guild_count=true
				pluralkit__scheduled_tasks__expected_gateway_count=57
				pluralkit__scheduled_tasks__gateway_url="pluralkit-gateway.service.consul:5000"

				pluralkit__db__data_db_uri="postgresql://pluralkit@database-hrhel1-251b75a5.vpn.pluralkit.net:5432/pluralkit"
				pluralkit__db__messages_db_uri="postgresql://pluralkit@database-hrhel1-251b75a5.vpn.pluralkit.net:5434/messages"
				pluralkit__db__stats_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5435/stats"
				pluralkit__db__data_redis_addr="redis://database-hrhel1-251b75a5.vpn.pluralkit.net:6379"

        pluralkit__discord__api_base_url="nirn-proxy.service.consul:8002"

        pluralkit__discord__client_id=1
        pluralkit__discord__client_secret=1
        pluralkit__discord__max_concurrency=1
			}

			service {
				name = "metrics"
				address_mode = "driver"
				port = 9000
			}
		}
	}
}

