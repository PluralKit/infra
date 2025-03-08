job "app_gateway" {
	datacenters = ["dc1"]

  # The "update" stanza specifies the update strategy of task groups. The update
  # strategy is used to control things like rolling upgrades, canaries, and
  # blue/green deployments.
  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "1m"

    # deadline to mark allocations as healthy
    # todo: this is probably way too high
    progress_deadline = "10m"

    # whether the job should auto-revert to the last stable job on deployment failure
    auto_revert = false
  }

  # same as above, but for migrating off of draining nodes
  migrate {
    max_parallel = 1
    health_check = "task_states"
    min_healthy_time = "10s"
    healthy_deadline = "1m"
  }

	vault {
	  policies = ["read-kv"]
	}

  constraint {
    attribute = "${node.class}"
    value = "compute"
  }

	group "gateway" {
		count = 54
	  network {
	    port "port" {
	      to = 5000
	    }
	  }

	  task "gateway" {
	    driver = "docker"
	    config {
	      image = "ghcr.io/pluralkit/gateway:version"
				labels = { pluralkit_rust = "true" }
        advertise_ipv6_address = true
	    }

			template {
				data = <<EOH
				{{ with secret "kv/pluralkit" }}
				pluralkit__db__db_password={{ .Data.databasePassword }}
        pluralkit__discord__bot_token={{ .Data.discordToken }}
				pluralkit__sentry_url={{ .Data.avatarsSentryUrl }}
				{{ end }}

			  pluralkit__discord__cluster__node_id=${NOMAD_ALLOC_INDEX}
				EOH

				destination = "local/env"
				env = true
			}

			env {
				RUST_LOG="info"
				pluralkit__json_log=true

        pluralkit__discord__client_id=466378653216014359

        pluralkit__discord__cluster__total_shards=864
        pluralkit__discord__cluster__total_nodes=54
        pluralkit__discord__max_concurrency=16
        pluralkit__discord__api_base_url="nirn-proxy.service.consul:8002"

				pluralkit__db__data_db_uri="postgresql://pluralkit@db.svc.pluralkit.net:5432/pluralkit"
				pluralkit__db__data_redis_addr="redis://db.svc.pluralkit.net:6379"

				pluralkit__run_metrics_server=true

				pluralkit__api__temp_token2=1
				pluralkit__api__remote_url=1
				pluralkit__api__ratelimit_redis_addr=1
        pluralkit__discord__client_secret=1
			}

			service {
				 name = "pluralkit-gateway"
				 tags = ["cluster${NOMAD_ALLOC_INDEX}"]
				 address_mode = "driver"
				 port = "port"
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
				memory = 1300
			}
	  }
	}
}
