job "folio" {
  datacenters = ["dc1"]
  type        = "service"

  group "folio" {

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

      auto_promote     = true
      canary           = 1
    }

    service {
      name = "folio"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.folio.tls=true",
	    "traefik.http.routers.folio.tls.certresolver=home",
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
  	    to = 8000
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "philipcristiano/folio:sha-9ee5620"
        ports = ["http"]
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "local/folio.env"
          env = true
          data = <<EOF
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
PGHOST=folio-postgres.{{ key "site/domain" }}
PGPORT={{ key "traefik-ports/folio-postgres" }}
PGUSER={{ key "credentials/folio-postgres/USER" }}
PGPASSWORD={{ key "credentials/folio-postgres/PASSWORD" }}
PGDATABASE={{ key "credentials/folio-postgres/DB" }}
PG_POOL_SIZE=20
EOF
      }
      template {
          data = <<EOF
          [{folio, [{is_local_dev, false}]}].
          EOF

      destination = "local/app.config"
      }

      resources {
        cpu    = 125
        memory = 512
      }

    }
  }
}
