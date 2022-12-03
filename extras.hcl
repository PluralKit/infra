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
				image = "ghcr.io/pluralkit/scheduled_tasks:98b6e726e7c9ced491cbbd20968310084beb5698"
			}

			template {
				data = <<EOD
					{{ with secret "kv/pluralkit" }}
					SENTRY_DSN={{ .Data.scheduledTasksSentryUrl }}
					DATA_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@10.0.1.3:5432/pluralkit
					MESSAGES_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@10.0.1.3:5432/pluralkit
					STATS_DB_URI=postgresql://pluralkit:{{ .Data.databasePassword }}@10.0.1.3:5433/stats
					REDIS_ADDR=10.0.1.3:6379
					{{ end }}
				EOD
				destination = "local/secret.env"
				env = true
			}
		}
	}

	group "postgres-exporter" {
		network {
			port "port" {
				static = 9187
				to = 9187
			}
		}

		# really this should be the other way around, but works for now
		constraint {
			attribute = "${attr.unique.hostname}"
			operator = "!="
			value = "ubuntu-4gb-fsn1-1"
		}

		task "postgres-exporter" {
			driver = "docker"
			config {
				image = "quay.io/prometheuscommunity/postgres-exporter"
				ports = ["port"]
			}

			template {
				data = <<EOD
					{{ with secret "kv/pluralkit" }}
					DATA_SOURCE_NAME=postgresql://pluralkit:{{ .Data.databasePassword }}@10.0.1.3:5432/pluralkit?sslmode=disable
					{{ end }}
				EOD
				destination = "local/secret.env"
				env = true
			}
		}
	}
}