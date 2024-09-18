job "pluralkit" {
  name = "pluralkit"
  datacenters = ["dc1"]

  constraint {
    attribute = "${attr.unique.hostname}"
    value = "compute03"
  }

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

  group "bot" {
    count = 48

    task "bot" {
      driver = "docker"
      config {
        image = "ghcr.io/pluralkit/pluralkit:version"
      }

      template {
          data = <<EOD
            {{ with secret "kv/pluralkit" }}
            PluralKit__Bot__Token = "{{ .Data.discordToken }}"
            PluralKit__DatabasePassword = "{{ .Data.databasePassword }}"
            PluralKit__SentryUrl = "{{ .Data.sentryUrl }}"
            PluralKit__DispatchProxyToken = {{ .Data.dispatchToken }}
            {{ end }}
          EOD
          destination = "local/secret.env"
          env = true
      }

      env {
        PluralKit__Bot__ClientId = 466378653216014359
        PluralKit__Bot__AdminRole = 913986523500777482
        PluralKit__Bot__DiscordBaseUrl = "http://100.99.134.112:8001/api/v10"
        PluralKit__Bot__HttpCacheUrl = "http://pluralkit-gateway.service.consul:5000"
        PluralKit__Bot__AvatarServiceUrl = "http://pluralkit-avatars.service.consul:3000"

        PluralKit__Bot__MaxShardConcurrency = 16
        PluralKit__Bot__UseRedisRatelimiter = true

        PluralKit__Bot__Cluster__TotalShards = 768
        PluralKit__Bot__Cluster__TotalNodes = 48
        
        PluralKit__Database = "Host=10.0.1.6;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=25;Minimum Pool Size = 25;Max Auto Prepare=25"
        PluralKit__MessagesDatabase = "Host=10.0.1.6;Port=5434;Username=pluralkit;Database=messages;Maximum Pool Size=25;Minimum Pool Size = 25;Max Auto Prepare=25"
        PluralKit__RedisAddr = "10.0.1.6:6379,abortConnect=false"
        PluralKit__InfluxUrl = "http://10.0.1.6:8086"
        PluralKit__InfluxDb = "pluralkit"
        PluralKit__UseRedisMetrics = true
        PluralKit__SeqLogUrl = "http://10.0.1.6:5341"
        PluralKit__DispatchProxyUrl = "http://dispatch.svc.pluralkit.net"

        PluralKit__ConsoleLogLevel = 2
        PluralKit__ElasticLogLevel = 1

        # we can't outright disable file logging in config, but it's not useful at all (loses events often) and takes up way too much disk space
        # so we only log "fatal" events (if the bot crashes)
        PluralKit__FileLogLevel = 5
      }

      # todo: add healthcheck

      resources {
        cpu    = 501
        memory = 1200
      }
    }
  }
}
