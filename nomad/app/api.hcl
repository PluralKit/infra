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
		count = 2

		task "api" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/pluralkit:image"
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
					PluralKit__SentryUrl = "{{ .Data.dotnetApiSentryUrl }}"
					{{ end }}
				EOH

				destination = "local/env"
				env = true
			}

			env {
				PluralKit__Api__ClientId = 466378653216014359
				PluralKit__Api__TrustAuth = true

				PluralKit__Database = "Host=database-hrhel1-251b75a5.vpn.pluralkit.net;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__MessagesDatabase = "Host=database-hrhel1-251b75a5.vpn.pluralkit.net;Port=5434;Username=pluralkit;Database=messages;Maximum Pool Size=150;Minimum Pool Size = 50;Max Auto Prepare=50"
				PluralKit__RedisAddr = "database-hrhel1-251b75a5.vpn.pluralkit.net:6379,abortConnect=false"
				PluralKit__ElasticUrl = "http://es.svc.pluralkit.net"

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
				image = "ghcr.io/pluralkit/api:image"
				labels = { pluralkit_rust = "true" }
        advertise_ipv6_address = true
			}

			template {
				data = <<EOH
				{{ with secret "kv/pluralkit" }}
				pluralkit__api__temp_token2={{ .Data.api_token2 }}
				pluralkit__db__db_password={{ .Data.databasePassword }}
				pluralkit__sentry_url={{ .Data.rustApiSentryUrl }}
				{{ end }}
				EOH

				destination = "local/env"
				env = true
			}

			env {
				RUST_LOG="info"
				pluralkit__json_log=true

				pluralkit__db__data_db_uri="postgresql://pluralkit@database-hrhel1-251b75a5.vpn.pluralkit.net:5432/pluralkit"
				pluralkit__db__data_redis_addr="redis://database-hrhel1-251b75a5.vpn.pluralkit.net:6379"
				pluralkit__api__ratelimit_redis_addr="redis://database-hrhel1-251b75a5.vpn.pluralkit.net:6379"

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

			resources {
        cpu = 500
        memory = 1000
      }
		}
	}
}
