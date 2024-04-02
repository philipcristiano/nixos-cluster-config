variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "philipcristiano/nomad-events-logger:0.1.3"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}


job "nomad-events-logger" {
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
      name = "nomad-events-logger"

      check {
        name     = "version"
        type     = "script"
        task     = "app"

        command   = "/usr/local/bin/nomad_events_logger"
        args      = ["-V"]

        interval = "30s"
        timeout  = "2s"
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-nomad-events-logger"]
      }

      config {
        image = var.image_id
        command = "nomad_events_logger"
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

      resources {
        cpu    = 10
        memory = 16
        memory_max = 64
      }

    }
  }
}
