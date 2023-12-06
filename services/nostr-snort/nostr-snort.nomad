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
  default     = "dockurr/snort:0.1.23"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "nostr-snort" {
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
      name = "snort"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.snort.tls=true",
	      "traefik.http.routers.snort.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	    to = 80
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]

      }

      resources {
        cpu    = 50
        memory = 32
        memory_max = 512
      }

    }
  }
}



