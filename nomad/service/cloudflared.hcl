job "service_cloudflared" {
  datacenters = ["dc1"]
  type = "system"

	vault {
		policies = ["read-kv"]
	}

  constraint {
    attribute = "${node.class}"
    value = "edge"
  }

  group "cloudflared" {
    task "cloudflared" {
      driver = "docker"

      config {
        image = "cloudflare/cloudflared"
        entrypoint = [ "cloudflared", "tunnel", "run" ]
      }

			template {
				data = <<EOH
				{{ with secret "kv/service" }}
				TUNNEL_TOKEN={{ .Data.cloudflaredToken }}
				{{ end }}

				EOH

				destination = "local/env"
				env = true
			}
    }
  }
}
