variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = ""
}

job "grafana-to-ntfy" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {


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
      name = "grafana-to-ntfy"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.grafana-to-ntfy.tls=true",
	      "traefik.http.routers.grafana-to-ntfy.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
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
        policies = ["service-grafana-to-ntfy"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

      }

      resources {
        cpu    = 100
        memory = 32
        memory_max = 128
      }

      template {
      	  destination = "secrets/config.yml"
          env = true
          data = <<EOF

NTFY_URL=https://ntfy.{{key "site/domain"}}/grafana
{{ with secret "kv/data/grafana-to-ntfy" }}
BAUTH_USER={{.Data.data.BAUTH_USER}}
BAUTH_PASS={{.Data.data.BAUTH_PASS}}
{{ end }}

EOF
      }

    }
  }
}



