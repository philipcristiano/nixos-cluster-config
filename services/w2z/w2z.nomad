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
}

job "w2z" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = 2

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
    }

    service {
      name = "w2z"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.w2z.tls=true",
        "traefik.http.routers.w2z.tls.certresolver=home",

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
        to = 3000
        host_network = "services"
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-w2z"]
      }

      config {
        # entrypoint = ["sleep", "10000"]
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        args = [
          "--bind-addr", "0.0.0.0:3000",
          "--config-file", "/local/config.toml",
          "--log-level", "INFO",
        ]
      }
      template {
          destination = "local/otel.env"
          env = true
          data = <<EOF
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://tempo-otlp-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc

EOF
      }

      template {
          destination = "local/config.toml"
          data = <<EOF

{{with secret "kv/data/w2z"}}

[auth]
issuer_url = "https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OIDC_CLIENT_ID }}"
redirect_url = "https://w2z.{{ key "site/domain" }}/oidc/login_auth"
client_secret = "{{.Data.data.OIDC_CLIENT_SECRET }}"
client_id = "{{.Data.data.OIDC_CLIENT_ID }}"
post_auth_path = "/"

[github]
token = "{{ .Data.data.GITHUB_TOKEN }}"
owner = "philipcristiano"
repository = "philipcristiano.com"
branch = "main"

{{end}}

EOF
      }


      resources {
        cpu    = 5
        memory = 12
        memory_max = 24
      }

    }
  }
}
