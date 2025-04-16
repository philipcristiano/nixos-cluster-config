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

job "docker-prefetch-image" {
  datacenters = ["dc1"]
  type        = "system"

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
      name = "docker-prefetch-image"

      check {
        name     = "version"
        type     = "script"
        task     = "app"

        command   = "/usr/local/bin/docker-prefetch-image"
        args      = ["-h"]

        interval = "30s"
        timeout  = "2s"
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-docker-prefetch-image"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        args = [
          "-c", "local/config.toml"
        ]

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]

      }

      template {
          destination = "local/app.env"
          env = true
          data = <<EOF

OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc

NOMAD_BASE_URL="http://nomad.{{ key "site/domain"}}"

EOF
      }

      template {
          destination = "local/config.toml"
          data = <<EOF

{{ range ls "docker-prefetch" }}
[[image]]
# {{ .Key }}
# This configuration assumes all images are sourced from Docker Hub and don't
# need an repo processing. The `image` can be prefixed with the local registry.
# The alternatives can be used "as-is"
image = "docker-registry.{{ key "site/domain" }}/{{.Value}}"
alternative_images = ["{{.Value}}"]
{{ end }}

{{- range $key, $pairs := tree "docker-prefetch-full" | byKey -}}
[[image]]
# {{ .Key }}
  {{- range $pair := $pairs }}
{{ .Key }} = {{ .Value }}
  {{- end }}
{{ end }}

[[image]]
image = "docker-registry.{{ key "site/domain" }}/busybox:latest"

[[image]]
image = "docker-registry.{{ key "site/domain" }}/philipcristiano/gocast:sha-a00e6fd"


EOF
      }
      resources {
        cpu    = 10
        memory = 16
        memory_max = 64
      }

    }
  }
}
