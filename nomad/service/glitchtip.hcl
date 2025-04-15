job "service_glitchtip" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${node.class}"
    value = "compute"
  }

  vault {
    policies = ["read-kv"]
  }

  group "valkey" {
    task "glitchtip-valkey" {
      driver = "docker"
      config {
        image = "valkey/valkey:latest"
        advertise_ipv6_address = true
      }

      resources {
        memory = 2000
      }

      service {
        name = "glitchtip-valkey"
        address_mode = "driver"
        provider = "consul"
      }
    }
  }

  group "glitchtip" {
    task "glitchtip-web" {
      driver = "docker"
      config {
        image = "glitchtip/glitchtip:v4.1"
        advertise_ipv6_address = true
      }

      template {
        data = <<EOD
          {{ with secret "kv/service" }}
          DATABASE_URL = "postgres://glitchtip:{{ .Data.glitchtipDatabasePassword }}@db.svc.pluralkit.net:5435/glitchtip"
          SECRET_KEY = "{{ .Data.glitchtipSecretKey }}"
          {{ end }}
        EOD
        destination = "local/secret.env"
        env = true
      }

      env {
        REDIS_URL = "redis://glitchtip-valkey.service.consul:6379"
        PORT = "[::]:8000"
        EMAIL_URL = "consolemail://"
        GLITCHTIP_DOMAIN = "https://gt.pluralkit.me"
        CSRF_TRUSTED_ORIGINS = "https://gt.pluralkit.me"
        DEFAULT_FROM_EMAIL = "admin@pluralkit.me"
        CELERY_WORKER_AUTOSCALE = "1,3"
        CELERY_WORKER_MAX_TASKS_PER_CHILD = "10000"
        ENABLE_USER_REGISTRATION = "false"
      }

      service {
        name = "glitchtip"
        address_mode = "driver"
        provider = "consul"
      }
    }

    task "glitchtip-worker" {
      driver = "docker"
      config {
        image = "glitchtip/glitchtip:v4.1"
        command = "./bin/run-celery-with-beat.sh"
      }

      template {
        data = <<EOD
          {{ with secret "kv/service" }}
          DATABASE_URL = "postgres://glitchtip:{{ .Data.glitchtipDatabasePassword }}@db.svc.pluralkit.net:5435/glitchtip"
          SECRET_KEY = "{{ .Data.glitchtipSecretKey }}"
          {{ end }}
        EOD
        destination = "local/secret.env"
        env = true
      }

      env {
        REDIS_URL = "redis://glitchtip-valkey.service.consul:6379"
        PORT = "8000"
        EMAIL_URL = "consolemail://"
        GLITCHTIP_DOMAIN = "https://gt.pluralkit.me"
        DEFAULT_FROM_EMAIL = "admin@pluralkit.me"
        CELERY_WORKER_AUTOSCALE = "1,3"
        CELERY_WORKER_MAX_TASKS_PER_CHILD = "10000"
        ENABLE_USER_REGISTRATION = "false"
      }
    }

    task "glitchtip-migrate" {
      driver = "docker"
      config {
        image = "glitchtip/glitchtip:v4.1"
        command = "./bin/run-migrate.sh"
      }

      lifecycle {
        hook = "prestart"
      }

      template {
        data = <<EOD
          {{ with secret "kv/service" }}
          DATABASE_URL = "postgres://glitchtip:{{ .Data.glitchtipDatabasePassword }}@db.svc.pluralkit.net:5435/glitchtip"
          SECRET_KEY = "{{ .Data.glitchtipSecretKey }}"
          {{ end }}
        EOD
        destination = "local/secret.env"
        env = true
      }

      env {
        REDIS_URL = "redis://glitchtip-valkey.service.consul:6379"
        PORT = "8000"
        EMAIL_URL = "consolemail://"
        GLITCHTIP_DOMAIN = "https://gt.pluralkit.me"
        DEFAULT_FROM_EMAIL = "admin@pluralkit.me"
        CELERY_WORKER_AUTOSCALE = "1,3"
        CELERY_WORKER_MAX_TASKS_PER_CHILD = "10000"
        ENABLE_USER_REGISTRATION = "false"
      }
    }
  }
}
