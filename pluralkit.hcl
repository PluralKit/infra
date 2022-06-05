job "pluralkit" {
  name = "pluralkit"
  datacenters = ["dc1"]

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

  group "bot" {
    count = 20

    task "bot" {
      driver = "docker"
      config {
        image = "ghcr.io/pluralkit/pluralkit:989a8b4453a50a634a69346fe6c1464235e4aca8"
        entrypoint = ["/app/scripts/run-clustered.sh"]
      }

      env {
        MGMT = "http://10.0.0.2:8081"
      }

      # todo: add healthcheck

      resources {
        cpu    = 500
        memory = 1200
      }
    }
  }
}
