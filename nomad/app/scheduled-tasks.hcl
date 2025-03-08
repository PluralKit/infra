job "app_scheduled-tasks" {
	datacenters = ["dc1"]

	vault {
		policies = ["read-kv"]
	}

  constraint {
    attribute = "${node.class}"
    value = "compute"
  }

	group "scheduled_tasks" {
		task "scheduled_tasks" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/scheduled_tasks:version"
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
				pluralkit__scheduled_tasks__expected_gateway_count=54
				pluralkit__scheduled_tasks__gateway_url="pluralkit-gateway.service.consul:5000"

				pluralkit__db__data_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5432/pluralkit"
				pluralkit__db__messages_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5434/messages"
				pluralkit__db__stats_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5435/stats"
				pluralkit__db__data_redis_addr="redis://db.svc.pluralkit.net:6379"

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
