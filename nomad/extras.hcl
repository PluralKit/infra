job "extras" {
	name = "extras"
	datacenters = ["dc1"]

	vault {
		policies = ["read-kv"]
	}

	group "scheduled_tasks" {
		task "scheduled_tasks" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/scheduled_tasks:version"
			}

			template {
				data = <<EOD
					{{ with secret "kv/pluralkit" }}
					SENTRY_DSN={{ .Data.scheduledTasksSentryUrl }}
					DATA_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@10.0.1.3:5432/pluralkit
					MESSAGES_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@10.0.1.3:5434/messages
					STATS_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@10.0.1.3:5433/stats
					REDIS_ADDR=10.0.1.3:6379
					SET_GUILD_COUNT=true
					{{ end }}
				EOD
				destination = "local/secret.env"
				env = true
			}
		}
	}
}