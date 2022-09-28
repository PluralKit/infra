job "web-services" {
	name = "web-services"
	datacenters = ["dc1"]

	vault {
		policies = ["read-kv"]
	}

	group "api" {
		network {
			port "port" {
				to = 8080
			}

			port "inner" {
				to = 5000
			}
		}

		constraint {
			attribute = "${attr.unique.hostname}"
			operator = "!="
			value = "ubuntu-4gb-fsn1-1"
		}

		task "proxy" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/api-proxy"
				ports = ["port"]
			}

			template {
				data = <<EOH
					REDIS_ADDR=10.0.1.3:6379
					{{ with secret "kv/pluralkit" }}
					TOKEN2={{ .Data.api_token2 }}
					{{ end }}
					{{ range nomadService "api-inner" }}
					REMOTE_ADDR=http://{{ .Address }}:{{ .Port }}
					{{ end }}
				EOH

				destination = "local/env"
				env = true
			}

			service {
				name = "api"
				port = "port"
				provider = "nomad"
			}
		}

		task "api" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/pluralkit:62c5c3865a77cc3becd3c1e8e36e91637741e15d"
				entrypoint = ["dotnet", "bin/PluralKit.API.dll"]
				ports = ["inner"]
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

				PluralKit__Database = "Host=10.0.1.3;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=300;Minimum Pool Size = 100;Max Auto Prepare=100"
				PluralKit__RedisAddr = "10.0.1.3:6379"
				PluralKit__ElasticUrl = "http://10.0.1.3:9200"

				PluralKit__ConsoleLogLevel = 2
				PluralKit__ElasticLogLevel = 2
				PluralKit__FileLogLevel = 5
			}

			service {
				name = "api-inner"
				port = "inner"
				provider = "nomad"
			}
		}
	}

	group "dashboard" {
		network {
			port "port" {
				to = 8080
			}
		}

		task "dashboard" {
			driver = "docker"
			config {
				image = "ghcr.io/pluralkit/dashboard:371d677af1fe7377e70f1a22066c9ccd174f318e"
				ports = ["port"]
			}

			service {
				name = "dashboard"
				port = "port"
				provider = "nomad"
			}
		}
	}

	group "caddy" {
		volume "data" {
			type = "host"
			read_only = false
			source = "caddy_data"
		}

		network {
			port "http" {
				static = 80
				to = 80
			}
			port "https" {
				static = 443
				to = 443
			}
		}

		task "caddy" {
			driver = "docker"
			config {
				image = "caddy"
				ports = ["http", "https"]
				entrypoint = ["/bin/sh", "-c", "caddy run --config /local/Caddyfile"]
			}

			template {
				data = <<EOH
					"dash.pluralkit.me" {
						reverse_proxy {{ range nomadService "dashboard" }} http://{{ .Address }}:{{ .Port }} {{ end }}
					}

					"api.pluralkit.me" {
						reverse_proxy {{ range nomadService "api" }} http://{{ .Address }}:{{ .Port }} {{ end }} {
							header_up X-Real-IP {remote_host}
						}
					}

					"stats.pluralkit.me" {
						reverse_proxy http://10.0.1.2:3000
					}

					"sentry.pluralkit.me" {
						reverse_proxy http://10.0.1.2:9000 {
							header_up -Connection
						}
					}

					"plausible.pluralkit.me" {
						reverse_proxy http://10.0.1.2:8000
					}

					"pk-webs.spectralitree.com" {
						redir https://dash.pluralkit.me{uri} permanent
					}

					"pk-webs-beta.spectralitree.com" {
						redir https://dash.pluralkit.me{uri} permanent
					}
				EOH
			
				destination = "local/Caddyfile"
			}

			volume_mount {
				volume = "data"
				destination = "/data/caddy"
			}
		}
	}
}