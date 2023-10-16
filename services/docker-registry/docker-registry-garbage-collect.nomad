
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
  description = "The docker image used for compute task."
}

job "docker-registry-garbage-collect" {
  datacenters = ["dc1"]
  type        = "batch"

  periodic {
    cron             = "0 22 * * * *"
    prohibit_overlap = true
  }

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "docker-registry-garbage-collect"

      check {
        name     = "docker-registry-garbage-collect"
        type     = "script"
        task     = "app"
        command   = "registry"
        args      = ["-h"]
        interval = "10s"
        timeout  = "2s"
      }
    }


    task "app" {
      driver = "docker"

      vault {
        policies = ["service-docker-registry"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        args = [
          "registry",
          "garbage-collect",
          "--dry-run",
          "/secrets/config.yml"
        ]

      }

      resources {
        cpu    = 20
        memory = 64
        memory_max = 512
      }

      template {
        destination = "secrets/config.yml"
        data = file("config.yml")
      }

    }
  }
}
