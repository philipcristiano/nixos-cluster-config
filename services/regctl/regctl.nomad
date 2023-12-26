variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = "ghcr.io/"
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "regclient/regctl:v0.5.6"
}

job "regctl-img-copy" {
  datacenters = ["dc1"]
  type        = "batch"

  parameterized {
    meta_optional = ["source_registry"]
    meta_required = ["image"]
    payload = "forbidden"
  }

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "regctl"
    }

    task "app" {
      driver = "docker"

      config {
        # entrypoint = ["sleep", "10000"]
        image = "${var.docker_registry}${var.image_id}"

        args = [
          "image",
          "copy",
          "${NOMAD_META_source_registry}${NOMAD_META_image}",
          "${SITE_REGISTRY}${NOMAD_META_image}",
        ]

      }

      template {
          destination = "local/otel.env"
          env = true
          data = <<EOF

SITE_REGISTRY="docker-registry.{{key "site/domain" }}/"

EOF
      }

      resources {
        cpu    = 125
        memory = 256
        memory_max = 1024
      }

    }
  }
}
