job "api" {
	name = "api"
	datacenters = ["dc1"]

	vault {
		policies = ["read-kv"]
	}

	group "api" {
		network {
			port "external" {
				to = 5000
			}

			port "inner" {
				to = 5000
			}
		}

		task "api" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/pluralkit:version"
				entrypoint = ["dotnet", "bin/PluralKit.API.dll"]
			}

			resources {
				memory = 600
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
				PluralKit__Api__TrustAuth = true

				PluralKit__Database = "Host=10.0.1.6;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__MessagesDatabase = "Host=10.0.1.6;Port=5434;Username=pluralkit;Database=messages;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__RedisAddr = "10.0.1.6:6379,abortConnect=false"
				PluralKit__ElasticUrl = "http://10.0.1.6:9200/dotnet"
				PluralKit__InfluxUrl = "http://10.0.1.6:8086"
				PluralKit__InfluxDb = "pluralkit"

				PluralKit__ConsoleLogLevel = 2
				PluralKit__ElasticLogLevel = 2
				PluralKit__FileLogLevel = 5
			}

			service {
				name = "pluralkit-dotnet-api"
				address_mode = "driver"
				port = "inner"
				provider = "consul"
			}
		}

		task "proxy" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/api:version"
				ports = ["external"]
			}

			service {
				name = "pluralkit-api"
				address_mode = "driver"
				port = "external"
				provider = "consul"
			}

			template {
				data = <<EOH
				{{ with secret "kv/pluralkit" }}
				pluralkit__api__temp_token2={{ .Data.api_token2 }}
				pluralkit__db__db_password={{ .Data.databasePassword }}
				{{ end }}

				EOH

				destination = "local/env"
				env = true
			}

			env {
				RUST_LOG="debug"

				pluralkit__db__data_db_uri="postgresql://pluralkit@10.0.1.6:5432/pluralkit"
				pluralkit__db__data_redis_addr="redis://10.0.1.6:6379"
				pluralkit__api__ratelimit_redis_addr="redis://10.0.1.6:6379"

				pluralkit__api__remote_url="http://pluralkit-dotnet-api.service.consul:5000"

				pluralkit__discord__bot_token=1
				pluralkit__discord__client_id=1
				pluralkit__discord__client_secret=1
				pluralkit__run_metrics_server=false
			}
		}
	}
}
