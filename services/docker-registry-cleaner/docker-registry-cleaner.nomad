
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

job "docker-registry-cleaner" {
  datacenters = ["dc1"]
  type        = "batch"

  periodic {
    cron             = "0 21 * * * *"
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
      name = "docker-registry-cleaner"

      check {
        name     = "docker-registry-cleaner"
        type     = "script"
        task     = "app"
        command   = "docker-registry-cleaner"
        args      = ["-h"]
        interval = "10s"
        timeout  = "2s"
      }
    }


    task "app" {
      driver = "docker"

      vault {
        policies = ["service-docker-registry-cleaner"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        args = [
            "--registry=${REGISTRY}",
            "--last-updated-label=${LABEL}",
            "--keep-n=3",
        ]

      }

      resources {
        cpu    = 20
        memory = 64
        memory_max = 128
      }

      template {
          destination = "local/app.env"
          env = true
          data = <<EOF

REGISTRY="https://docker-registry.{{key "site/domain"}}"
LABEL="image.last-copied"

EOF
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }
    }
  }
}
