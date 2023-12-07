variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for compute task."
  default     = "redis:7.0.7"
}

variable "count" {
  type        = number
  description = "The number of compute containers to run."
  default     = "1"
}

variable "name" {
  type        = string
  description = "Name of this instance of Redis instance"
}

variable "domain" {
  type        = string
  description = "Domain name of this instance of Redis instance"
}

job "JOB_NAME-redis" {
  datacenters = ["dc1"]
  type        = "service"

  group "compute" {

    count = var.count

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "${var.name}-redis"
      port = "redis"

      tags = [
        "traefik.enable=true",
	      "traefik.tcp.routers.${var.name}-redis.tls=true",
	      "traefik.tcp.routers.${var.name}-redis.tls.certresolver=home",
        "traefik.tcp.routers.${var.name}-redis.entrypoints=redis",
        "traefik.tcp.routers.${var.name}-redis.rule=HostSNI(`${var.name}-redis.${var.domain}`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "redis"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {

      port "redis" {
        to = 6379
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-${ var.name }-redis"]

      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["redis"]

        args = ["/secrets/redis.conf"]

      }

      resources {
        cpu    = 50
        memory = 256
        memory_max = 2048
      }

      template {
        env = true
        data = <<EOF

OTEL_EXPORTER_OTLP_ENDPOINT=https://tempo-otlp-http.{{ key "site/domain" }}:443

EOF
        destination = "secrets/file.env"
      }

      template {
        data          = <<EOF

masteruser default

{{ with secret "kv/data/JOB_NAME-redis" }}
requirepass {{.Data.data.password}}
{{ end }}

loglevel verbose

EOF
        destination   = "secrets/redis.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

    }
  }
}
