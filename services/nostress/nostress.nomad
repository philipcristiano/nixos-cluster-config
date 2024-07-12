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
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "nostress" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
    }

    service {
      name = "nostress"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.nostress.tls=true",
	      "traefik.http.routers.nostress.tls.certresolver=home",
      ]

      check {
        name     = "loki"
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

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        args = [
          "--bind-addr", "0.0.0.0:3000",
          "--default-relay", "wss://relay.damus.io",
          "--default-relay", "wss://relay.snort.social",
        ]
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }

      resources {
        cpu    = 100
        memory = 32
        memory_max = 128
      }

    }
  }
}



