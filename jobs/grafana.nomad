variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "grafana/grafana-oss:9.5.2"
}

job "grafana" {
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
      name = "grafana"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.grafana.tls=true",
	    "traefik.http.routers.grafana.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
  	   to = 3000
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "grafana"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = var.image_id
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/var/lib/grafana"
      }

      template {
          destination = "local/app.env"
          env = true
          data = <<EOF
GF_SERVER_ROOT_URL="https://grafana.{{ key "site/domain" }}"
GF_RENDERING_SERVER_URL="https://grafana-image-renderer.{{ key "site/domain" }}/render"
GF_RENDERING_CALLBACK_URL="https://grafana.{{ key "site/domain" }}"
GF_LOG_FILTERS="rendering:debug"

EOF
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}
