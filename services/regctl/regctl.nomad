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
      attempts = 3
      interval = "15m"
      delay    = "30s"
      mode     = "fail"
    }

    service {
      name = "regctl"
    }

    task "copy" {
      driver = "docker"

      vault {
        policies = ["service-regctl"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        args = [
          "-v",
          "debug",
          "--host", "${AUTH}",
          "image",
          "copy",
          "${NOMAD_META_source_registry}${NOMAD_META_image}",
          "${SITE_REGISTRY}${NOMAD_META_image}",
        ]

      }

      template {
          destination = "local/app.env"
          env = true
          data = <<EOF

{{ with secret "kv/data/regctl" }}
AUTH=reg="docker.io,user={{.Data.data.USERNAME}},pass={{.Data.data.PASSWORD}}"
{{ end }}
SITE_REGISTRY="docker-registry.{{key "site/domain" }}/"

EOF
      }
    }

    task "label" {
      driver = "docker"

      lifecycle {
        hook = "poststop"
        sidecar = false
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        args = [
          "-v",
          "debug",
          "image",
          "mod",
          "${SITE_REGISTRY}${NOMAD_META_image}",
          "--replace",
          "--label=image.last-copied=${JOB_START}",
        ]

      }

      template {
          destination = "local/app.env"
          env = true
          data = <<EOF

SITE_REGISTRY="docker-registry.{{key "site/domain" }}/"
JOB_START="{{timestamp}}"

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
