variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "registry.gitlab.com/hectorjsmith/grafana-matrix-forwarder:0.7.0"
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
    }

    task "app" {
      driver = "docker"

      config {
        image = var.image_id
        #entrypoint = ["sleep", "10000"]
        ports = ["http"]

      }
      template {
          destination = "local/app.env"
          env = true
          data = <<EOF
GMF_MATRIX_HOMESERVER="https://matrix.{{ key "site/domain" }}"
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
