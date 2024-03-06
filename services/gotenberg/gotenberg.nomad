variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

job "gotenberg" {
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
      name = "gotenberg"
      port = "http"

      tags = [
        "prometheus",
        "traefik.enable=true",
        "traefik.http.routers.gotenberg.tls=true",
        "traefik.http.routers.gotenberg.tls.certresolver=home",
      ]

      meta {
       metrics_path = "/prometheus/metrics"
      }

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
        path     = "/health"
      }
    }

    network {
      port "http" {
        to = 3000
      }

    }

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

        command = "gotenberg"
        args = [
            "uno-listener-restart-threshold",
            "0",
        ]

      }

      resources {
        cpu    = 500
        memory = 512
      }

      env {}

    }
  }
}
