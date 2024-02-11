job "api" {
	name = "api"
	datacenters = ["dc1"]

	constraint {
		attribute = "${attr.unique.hostname}"
		value = "ubuntu-4gb-fsn1-1"
	}

	vault {
		policies = ["read-kv"]
	}

	group "api" {
		network {
			port "port" {
				static = 5000
				to = 5000
				host_network = "6pn"
			}
		}

		task "api" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/pluralkit:version"
				entrypoint = ["dotnet", "bin/PluralKit.API.dll"]
				ports = ["port"]
			}

			template {
				data = <<EOH
					{{ with secret "kv/pluralkit" }}
					PluralKit__Api__ClientSecret = "{{ .Data.discordClientSecret }}"
					PluralKit__DatabasePassword = "{{ .Data.databasePassword }}"
					PluralKit__SentryUrl = "{{ .Data.sentryUrl }}"
					{{ end }}
				EOH

				destination = "local/env"
				env = true
			}

			env {
				PluralKit__Api__ClientId = 466378653216014359

				PluralKit__Database = "Host=10.0.1.3;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__MessagesDatabase = "Host=10.0.1.3;Port=5434;Username=pluralkit;Database=messages;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__RedisAddr = "10.0.1.3:6379"
				PluralKit__SeqLogUrl = "http://10.0.1.3:5341"
				PluralKit__InfluxUrl = "http://10.0.1.3:8086"
				PluralKit__InfluxDb = "pluralkit"

				PluralKit__ConsoleLogLevel = 2
				PluralKit__ElasticLogLevel = 2
				PluralKit__FileLogLevel = 5
			}
		}
	}
}