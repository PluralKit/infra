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
				image = "ghcr.io/pluralkit/scheduled_tasks:1c9b7fae99102029817b7d307f7380675fece6b0"
			}

			template {
				data = <<EOD
					{{ with secret "kv/pluralkit" }}
					SENTRY_DSN={{ .Data.scheduledTasksSentryUrl }}
					DATA_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@db.svc.pluralkit.net:5432/pluralkit
					MESSAGES_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@db.svc.pluralkit.net:5434/messages
					STATS_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@postgres-stats.service.consul:5432/stats
					{{ end }}
				EOD
				destination = "local/secret.env"
				env = true
			}

			env {
				REDIS_ADDR = "db.svc.pluralkit.net"
				SET_GUILD_COUNT = "false" # todo update this
			}

			service {
				name = "metrics"
				address_mode = "driver"
				port = 9000
			}
		}
	}
}
