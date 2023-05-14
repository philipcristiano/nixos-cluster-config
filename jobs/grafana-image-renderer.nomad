variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "grafana/grafana-image-renderer:3.7.0"
}

job "grafana-image-renderer" {
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
      name = "grafana-image-renderer"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.grafana-image-renderer.tls=true",
	    "traefik.http.routers.grafana-image-renderer.tls.certresolver=home",
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
  	   to = 8081
      }

    }

    task "app" {
      driver = "docker"

      config {
        image = var.image_id
        ports = ["http"]
      }

      resources {
        cpu    = 50
        memory = 128
        memory_max = 1024
      }

    }
  }
}
