variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "svix/svix-server:v1.7.0"
}

job "svix" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }
    service {
      name = "svix"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.svix.tls=true",
	      "traefik.http.routers.svix.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/api/v1/health/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	    to = 8071
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-svix"]
      }

      config {
        # entrypoint = ["sleep", "10000"]
        image = var.image_id
        ports = ["http"]
      }

      template {
          destination = "secrets/config.env"
          env = true
          data = <<EOF
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-http.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=http/json

RUST_BACKTRACE=full

SVIX_DB_DSN="postgresql://{{ key "credentials/svix-postgres/USER" }}:{{ key "credentials/svix-postgres/PASSWORD" }}@svix-postgres.{{ key "site/domain" }}:{{ key "traefik-ports/svix-postgres"}}/{{ key "credentials/svix-postgres/DB" }}"

{{with secret "kv/data/svix"}}
SVIX_JWT_SECRET={{.Data.data.jwt_secret}}
{{end}}

SVIX_CACHE_TYPE=redis

SVIX_QUEUE_TYPE=redis
SVIX_REDIS_DSN=redis://default:{{ key "credentials/svix-redis/password" }}@svix-redis.{{ key "site/domain" }}:{{ key "traefik-ports/svix-redis" }}

EOF
      }

      resources {
        cpu    = 125
        memory = 256
        memory_max = 2048
      }

    }
  }
}
