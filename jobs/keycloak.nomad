variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "quay.io/keycloak/keycloak:21.1.1"
}

job "keycloak" {
  datacenters = ["dc1"]
  type        = "service"

  group "keycloak" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }
    service {
      name = "keycloak"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.keycloak.tls=true",
	    "traefik.http.routers.keycloak.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	    to = 8080
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = var.image_id
        ports = ["http"]
        command = "start"

        hostname = "keycloak"
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "local/keycloak.env"
          env = true
          data = <<EOF


KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin

OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
KC_DB_URL_HOST=keycloak-postgres.{{ key "site/domain" }}
KC_DB=postgres
KC_DB_URL_PORT=5438
KC_DB_USERNAME={{ key "credentials/keycloak-postgres/USER" }}
KC_DB_PASSWORD={{ key "credentials/keycloak-postgres/PASSWORD" }}
KC_DB_URL_DATABASE={{ key "credentials/keycloak-postgres/DB" }}

KC_HOSTNAME_URL=https://keycloak.{{ key "site/domain" }}
KC_PROXY=edge

KC_HEALTH_ENABLED=true

EOF
      }

      resources {
        cpu    = 125
        memory = 512
        memory_max = 1024
      }

    }
  }
}
