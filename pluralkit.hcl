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

  vault {
    policies = ["read-kv"]
  }

  constraint {
    attribute = "${attr.unique.hostname}"
    operator = "!="
    value = "ubuntu-4gb-fsn1-1"
  }

  group "bot" {
    count = 24

    task "bot" {
      driver = "docker"
      config {
        image = "ghcr.io/pluralkit/pluralkit:65e2bb02346cc7e36a350af31aa9ed24b472ef39"
      }

      template {
          data = <<EOD
            {{ with secret "kv/pluralkit" }}
            PluralKit__Bot__Token = "{{ .Data.discordToken }}"
            PluralKit__DatabasePassword = "{{ .Data.databasePassword }}"
            PluralKit__SentryUrl = "{{ .Data.sentryUrl }}"
            {{ end }}
          EOD
          destination = "local/secret.env"
          env = true
      }

      env {
        PluralKit__Bot__ClientId = 466378653216014359
        PluralKit__Bot__AdminRole = 913986523500777482
        PluralKit__Bot__DiscordBaseUrl = "http://10.0.0.2:8001/api/v10"

        PluralKit__Bot__MaxShardConcurrency = 16
        PluralKit__Bot__UseRedisRatelimiter = true

        PluralKit__Bot__Cluster__TotalShards = 384
        PluralKit__Bot__Cluster__TotalNodes = 24
        
        PluralKit__Database = "Host=10.0.1.3;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=50;Minimum Pool Size = 50;Max Auto Prepare=50"
        PluralKit__RedisAddr = "10.0.1.3:6379"
        # PluralKit__ElasticUrl = "http://10.0.1.2:9200"
        PluralKit__InfluxUrl = "http://10.0.1.3:8086"
        PluralKit__InfluxDb = "pluralkit"
        PluralKit__UseRedisMetrics = true

        PluralKit__ConsoleLogLevel = 2
        PluralKit__ElasticLogLevel = 2

        # we can't outright disable file logging in config, but it's not useful at all (loses events often) and takes up way too much disk space
        # so we only log "fatal" events (if the bot crashes)
        PluralKit__FileLogLevel = 5
      }

      # todo: add healthcheck

      resources {
        cpu    = 500
        memory = 1200
      }
    }
  }
}
