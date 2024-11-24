job "service_glitchtip" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${node.class}"
    value = "compute"
  }

  vault {
    policies = ["read-kv"]
  }

  group "postgres" {
    volume "pg-data" {
      type            = "csi"
      source          = "glitchtip-postgres-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "glitchtip-postgres" {
      driver = "docker"

      config {
        image = "postgres:17"
        advertise_ipv6_address = true
      }

      volume_mount {
        volume = "pg-data"
        destination = "/var/lib/postgresql/data"
      }

      env {
        POSTGRES_PASSWORD = "postgres"
      }

			service {
				name = "glitchtip-postgres"
				address_mode = "driver"
				provider = "consul"
			}
    }
  }

  group "valkey" {
    task "glitchtip-valkey" {
      driver = "docker"
      config {
        image = "valkey/valkey:latest"
        advertise_ipv6_address = true
      }

      service {
        name = "glitchtip-valkey"
        address_mode = "driver"
        provider = "consul"
      }
    }
  }

  group "glitchtip" {
    volume "glitchtip-appdata" {
      type = "csi"
      source = "glitchtip-appdata"
      access_mode = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    task "glitchtip-web" {
      driver = "docker"
      config {
        image = "glitchtip/glitchtip"
        advertise_ipv6_address = true
      }

      template {
        data = <<EOD
          {{ with secret "kv/service" }}
          SECRET_KEY = "{{ .Data.glitchtipSecretKey }}"
          {{ end }}
        EOD
        destination = "local/secret.env"
        env = true
      }

      env {
        DATABASE_URL = "postgres://postgres:postgres@glitchtip-postgres.service.consul:5432/postgres"
        REDIS_URL = "redis://glitchtip-valkey.service.consul:6379"
        PORT = "[::]:8000"
        EMAIL_URL = "consolemail://"
        GLITCHTIP_DOMAIN = "https://gt.pluralkit.me"
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
        image = "glitchtip/glitchtip"
        command = "./bin/run-celery-with-beat.sh"
      }

      template {
        data = <<EOD
          {{ with secret "kv/service" }}
          SECRET_KEY = "{{ .Data.glitchtipSecretKey }}"
          {{ end }}
        EOD
        destination = "local/secret.env"
        env = true
      }

      env {
        DATABASE_URL = "postgres://postgres:postgres@glitchtip-postgres.service.consul:5432/postgres"
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
        image = "glitchtip/glitchtip"
        command = "./bin/run-migrate.sh"
      }

      lifecycle {
        hook = "prestart"
      }

      template {
        data = <<EOD
          {{ with secret "kv/service" }}
          SECRET_KEY = "{{ .Data.glitchtipSecretKey }}"
          {{ end }}
        EOD
        destination = "local/secret.env"
        env = true
      }

      env {
        DATABASE_URL = "postgres://postgres:postgres@glitchtip-postgres.service.consul:5432/postgres"
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
