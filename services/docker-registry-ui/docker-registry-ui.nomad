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
  default     = "joxit/docker-registry-ui:2.5.4-debian"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "docker-registry-ui" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"

      auto_promote     = true
      canary           = 1
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "docker-registry-ui"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.docker-registry-ui.tls=true",
	      "traefik.http.routers.docker-registry-ui.tls.certresolver=home",
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

      vault {
        policies = ["service-docker-registry-ui"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 512
        memory_max = 2048
      }

      template {
          destination = "local/subscriptions.yaml"
          env=true
          data = <<EOF
REGISTRY_TITLE=My Private Docker Registry
REGISTRY_URL=https://docker-registry.{{ key "site/domain"}}
SINGLE_REGISTRY=true
DELETE_IMAGES=true

EOF
      }
    }
  }
}



