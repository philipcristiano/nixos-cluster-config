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
        "traefik.http.routers.folio.middlewares=traefik-forward-auth",
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

      vault {
        policies = ["service-folio"]
      }

      config {
        image = "philipcristiano/folio:sha-b1d1a93"
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
OTEL_EXPORTER_OTLP_ENDPOINT=https://tempo-otlp-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc

{{with secret "kv/data/folio-postgres"}}
PGHOST=folio-postgres.{{ key "site/domain" }}
PGPORT=5457
PGUSER={{.Data.data.postgres_username}}
PGPASSWORD={{ .Data.data.postgres_password }}
PGDATABASE={{.Data.data.postgres_username}}
PG_POOL_SIZE=20

{{ end }}
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
