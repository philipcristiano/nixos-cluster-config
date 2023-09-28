variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "registry.gitlab.com/etke.cc/postmoogle:v0.9.16"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}


job "postmoogle" {
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
      name = "smtp"
      port = "smtp"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.smtp.entrypoints=smtp",
        "traefik.tcp.routers.smtp.rule=HostSNI(`*`)",
      ]

      check {
        name     = "smtp-listening"
        type     = "tcp"
        port     = "smtp"
        interval = "30s"
        timeout  = "2s"
      }
    }

    network {
      port "smtp" {
        to = 3000
      }
    }


    task "app" {
      driver = "docker"

      vault {
        policies = ["service-postmoogle"]
      }

      config {
        image = var.image_id
        ports = ["smtp"]
      }

      template {
          destination = "secrets/app.env"
          env = true
          data = <<EOF

OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc

POSTMOOGLE_HOMESERVER="https://matrix.{{ key "site/public_domain"}}"
POSTMOOGLE_PORT=3000


{{with secret "kv/data/postmoogle"}}
POSTMOOGLE_LOGIN = {{.Data.data.login }}
POSTMOOGLE_PASSWORD = {{.Data.data.password }}
POSTMOOGLE_DOMAINS = "{{ key "site/domain"}}  {{ key "site/public_domain"}} gmail.com"
POSTMOOGLE_ADMINS = "{{.Data.data.admins }}"

{{end}}


EOF
      }

      resources {
        cpu    = 10
        memory = 64
        memory_max = 256
      }

    }
  }
}
