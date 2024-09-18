job "gateway" {
	name = "gateway"
	datacenters = ["dc1"]

#	constraint {
#	  attribute = "${attr.unique.hostname}"
#	  value = "compute03"
#	}

  # The "update" stanza specifies the update strategy of task groups. The update
  # strategy is used to control things like rolling upgrades, canaries, and
  # blue/green deployments.
  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "1m"

    # The "progress_deadline" parameter specifies the deadline in which an
    # allocation must be marked as healthy. The deadline begins when the first
    # allocation for the deployment is created and is reset whenever an allocation
    # as part of the deployment transitions to a healthy state. If no allocation
    # transitions to the healthy state before the progress deadline, the
    # deployment is marked as failed.
    progress_deadline = "10m"

    # The "auto_revert" parameter specifies if the job should auto-revert to the
    # last stable job on deployment failure. A job is marked as stable if all the
    # allocations as part of its deployment were marked healthy.
    auto_revert = false
  }

  # The migrate stanza specifies the group's strategy for migrating off of
  # draining nodes.
  migrate {
    max_parallel = 1
    health_check = "task_states"
    min_healthy_time = "10s"
    healthy_deadline = "1m"
  }

	vault {
	  policies = ["read-kv"]
	}

	group "gateway" {
		count = 48
	  network {
	    port "port" {
	      to = 5000
	    }
	  }

	  task "gateway" {
	    driver = "docker"
	    config {
	      image = "ghcr.io/pluralkit/gateway:version"
	    }

			template {
				data = <<EOH
				{{ with secret "kv/pluralkit" }}
				pluralkit__db__db_password={{ .Data.databasePassword }}
        pluralkit__discord__bot_token={{ .Data.discordToken }}
				{{ end }}

			  pluralkit__discord__cluster__node_id=${NOMAD_ALLOC_INDEX}
				EOH

				destination = "local/env"
				env = true
			}

			service {
				 name = "pluralkit-gateway"
				 tags = ["cluster${NOMAD_ALLOC_INDEX}"]
				 address_mode = "driver"
				 port = "port"
				 provider = "consul"
			}

			env {
				RUST_LOG="debug"
				pluralkit__json_log=true

        pluralkit__discord__client_id=466378653216014359

        pluralkit__discord__cluster__total_shards=768
        pluralkit__discord__cluster__total_nodes=48
        pluralkit__discord__max_concurrency=16

				pluralkit__db__data_db_uri="postgresql://pluralkit@10.0.1.6:5432/pluralkit"
				pluralkit__db__data_redis_addr="redis://10.0.1.6:6379"

				pluralkit__run_metrics_server=false

				pluralkit__api__temp_token2=1
				pluralkit__api__remote_url=1
				pluralkit__api__ratelimit_redis_addr=1
        pluralkit__discord__client_secret=1
			}

			resources {
				cpu = 500
				memory = 1300
			}
	  }
	}
}
