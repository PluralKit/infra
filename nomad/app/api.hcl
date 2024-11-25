job "app_api" {
	datacenters = ["dc1"]

	vault {
		policies = ["read-kv"]
	}

  constraint {
    attribute = "${node.class}"
    value = "compute"
  }

	group "pluralkit-api" {
		task "api" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/pluralkit:f3e006034b19ef8bc5c45bc45d13e37ac0d812c2"
				entrypoint = ["dotnet", "bin/PluralKit.API.dll"]
        advertise_ipv6_address = true
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

				PluralKit__Database = "Host=db.svc.pluralkit.net;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__MessagesDatabase = "Host=db.svc.pluralkit.net;Port=5434;Username=pluralkit;Database=messages;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__RedisAddr = "db.svc.pluralkit.net:6379,abortConnect=false"
				PluralKit__InfluxUrl = "http://influxdb.service.consul:8086"
				PluralKit__InfluxDb = "pluralkit"
				PluralKit__ElasticUrl = "http://observability.svc.pluralkit.net:9200"

        PluralKit__DispatchProxyUrl = "http://dispatch.svc.pluralkit.net"
				PluralKit__ConsoleLogLevel = 2
				PluralKit__ElasticLogLevel = 2
				PluralKit__FileLogLevel = 5
			}

			service {
				name = "pluralkit-dotnet-api"
				address_mode = "driver"
				provider = "consul"
			}
		}

		task "pluralkit-api-proxy" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/api:701bafdf97349fef13ee2ba4651fe5b3a5fc80cc"
				labels = { pluralkit_rust = "true" }
        advertise_ipv6_address = true
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
				RUST_LOG="info"
				pluralkit__json_log=true

				pluralkit__db__data_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5432/pluralkit"
				pluralkit__db__data_redis_addr="redis://db.svc.pluralkit.net:6379"
				pluralkit__api__ratelimit_redis_addr="redis://db.svc.pluralkit.net:6379"

				pluralkit__api__addr="[::]:5000"
				pluralkit__api__remote_url="http://pluralkit-dotnet-api.service.consul:5000"

				pluralkit__run_metrics_server=true
			}

			service {
				name = "pluralkit-api"
				address_mode = "driver"
				provider = "consul"
			}

			service {
				name = "metrics"
				address_mode = "driver"
				port = 9000
				provider = "consul"
			}
		}
	}
}
