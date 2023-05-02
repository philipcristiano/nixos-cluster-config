job "baserow" {
  datacenters = ["dc1"]
  type        = "service"

  group "baserow" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }
    service {
      name = "baserow"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.baserow.tls=true",
	      "traefik.http.routers.baserow.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/_health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	    to = 80
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "baserow"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "prep-disk" {
      driver = "docker"
      volume_mount {
        volume      = "storage"
        destination = "/storage"
        read_only   = false
      }
      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R 9999:0 /storage && chmod 775 /storage"]
      }
      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "app" {
      driver = "docker"

      config {
        # entrypoint = ["sleep", "10000"]
        image = "baserow/baserow:1.16.0"
        ports = ["http"]
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "local/config.env"
          env = true
          data = <<EOF
BASEROW_ENABLE_OTEL=true
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-http.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=http/json
OTEL_RESOURCE_ATTRIBUTES="service.name=baserow"
OTEL_SERVICE_NAME=baserow_servicename

BASEROW_PUBLIC_URL=https://baserow.{{ key "site/domain" }}
DATABASE_HOST=baserow-postgres.{{ key "site/domain" }}
DATABASE_PORT=5436
DATABASE_USER={{ key "credentials/baserow-postgres/USER" }}
DATABASE_PASSWORD={{ key "credentials/baserow-postgres/PASSWORD" }}
DATABASE_NAME={{ key "credentials/baserow-postgres/DB" }}

REDIS_HOST=baserow-redis.{{ key "site/domain" }}
REDIS_PORT=6381
REDIS_USER=default
REDIS_PASSWORD={{ key "credentials/baserow-redis/password" }}

EOF
      }

      volume_mount {
        volume      = "storage"
        destination = "/baserow/data"
      }

      resources {
        cpu    = 125
        memory = 1024
        memory_max = 2048
      }

    }
  }
}
