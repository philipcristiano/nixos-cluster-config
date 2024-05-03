variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = "ghcr.io/"
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "miniflux" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "miniflux"
      port = "http"

      tags = [
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.miniflux.tls=true",
	      "traefik.http.routers.miniflux.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/healthcheck"
        interval = "10s"
        timeout  = "2s"

        check_restart {
          limit           = 5
          grace           = "30s"
          ignore_warnings = false
        }
      }
    }


    network {
      port "http" {
  	    to = 8080
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-miniflux"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]

      }


      resources {
        cpu    = 50
        memory = 128
        memory_max = 512
      }

      template {
          destination = "secrets/miniflux.env"
          env = true
          data = <<EOF

{{ with secret "kv/data/miniflux" }}
OAUTH2_PROVIDER=oidc
OAUTH2_CLIENT_ID={{.Data.data.OIDC_CLIENT_ID}}
OAUTH2_CLIENT_SECRET={{.Data.data.OIDC_CLIENT_SECRET}}
OAUTH2_REDIRECT_URL=https://miniflux.{{key "site/domain"}}/oauth2/oidc/callback
OAUTH2_OIDC_DISCOVERY_ENDPOINT=https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OIDC_CLIENT_ID }}
OAUTH2_USER_CREATION=1

{{ end }}

BASE_URL=https://miniflux.{{key "site/domain"}}
RUN_MIGRATIONS=1
LOG_FILE=stdout
LOG_FORMAT=json
METRICS_COLLECTOR=1
METRICS_ALLOWED_NETWORKS="10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,127.0.0.1/32"

LOG_LEVEL=debug
LOG_DATE_TIME=1

# Don't automatically disable feeds for parse errors
POLLING_PARSING_ERROR_LIMIT=0

POLLING_FREQUENCY=15
POLLING_SCHEDULER=entry_frequency

HTTP=1

{{ with secret "kv/data/miniflux-postgres" }}
DATABASE_URL=postgresql://{{.Data.data.USER}}:{{ .Data.data.PASSWORD }}@miniflux-postgres.{{ key "site/domain" }}:5457/{{.Data.data.DB}}?sslmode=verify-full

{{ end }}


EOF
      }
    }
  }
}



