variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = "registry.gitlab.com/"
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

job "grafana-matrix-forwarder" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    network {
      port "http" {
  	    to = 6000
      }
    }

    service {
      name = "grafana-matrix-forwarder"
      port = "http"

      tags = [
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.grafana-matrix-forwarder.tls=true",
        "traefik.http.routers.grafana-matrix-forwarder.entrypoints=http,https",
	      "traefik.http.routers.grafana-matrix-forwarder.tls.certresolver=home",
      ]

      check {
        name     = "http"
        type     = "http"
        port     = "http"
        path     = "/metrics"
        interval = "10s"
        timeout  = "2s"
      }

      check_restart {
        limit = 3
        grace = "90s"
        ignore_warnings = false
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        #entrypoint = ["sleep", "10000"]
        ports = ["http"]

      }
      template {
          destination = "local/app.env"
          env = true
          data = <<EOF
GMF_MATRIX_HOMESERVER="https://matrix.{{ key "site/public_domain" }}"
GMF_MATRIX_USER="{{ key "credentials/grafana-matrix-forwarder/user" }}"
GMF_MATRIX_PASSWORD="{{ key "credentials/grafana-matrix-forwarder/password" }}"

EOF
      }

      resources {
        cpu    = 50
        memory = 128
        memory_max = 512
      }

    }
  }
}
