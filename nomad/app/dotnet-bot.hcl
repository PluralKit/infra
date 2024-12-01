job "app_dotnet-bot" {
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

  group "bot" {
    count = 54

    task "bot" {
      driver = "docker"
      config {
        image = "ghcr.io/pluralkit/pluralkit:f3e006034b19ef8bc5c45bc45d13e37ac0d812c2"
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
        PluralKit__Bot__DiscordBaseUrl = "http://nirn-proxy.service.consul:8002/api/v10"
        PluralKit__Bot__HttpCacheUrl = "http://pluralkit-gateway.service.consul:5000"
        # PluralKit__Bot__HttpUseInnerCache = true
        PluralKit__Bot__AvatarServiceUrl = "http://pluralkit-avatars.service.consul:3000"

        PluralKit__Bot__MaxShardConcurrency = 16
        PluralKit__Bot__UseRedisRatelimiter = true

        PluralKit__Bot__Cluster__TotalShards = 864
        PluralKit__Bot__Cluster__TotalNodes = 54

        PluralKit__Database = "Host=db.svc.pluralkit.net;Port=5432;Username=pluralkit;Database=pluralkit;Maximum Pool Size=25;Minimum Pool Size = 25;Max Auto Prepare=25"
        PluralKit__MessagesDatabase = "Host=db.svc.pluralkit.net;Port=5434;Username=pluralkit;Database=messages;Maximum Pool Size=25;Minimum Pool Size = 25;Max Auto Prepare=25"
        PluralKit__RedisAddr = "db.svc.pluralkit.net:6379,abortConnect=false"
        PluralKit__InfluxUrl = "http://observability.svc.pluralkit.net:9090"
        PluralKit__InfluxDb = "pluralkit"
				PluralKit__ElasticUrl = "http://observability.svc.pluralkit.net:9200"
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
