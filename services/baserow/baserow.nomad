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
  default     = "baserow/baserow:1.21.2"
}

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

      check_restart {
        limit           = 5
        grace           = "60s"
        ignore_warnings = false
      }

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/_health"
        interval = "10s"
        timeout  = "2s"
      }

      check {
        name     = "backend-curl-http"
        type     = "script"
        task     = "app"
        interval = "15s"
        timeout  = "10s"
        command  = "curl"
        args     = ["-f", "127.0.0.1:8000/_health/"]
      }

      check {
        name     = "backend-cmd"
        type     = "script"
        task     = "app"
        interval = "30s"
        timeout  = "10s"
        command  = "/baserow.sh"
        args     = ["backend-cmd", "backend-healthcheck"]
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
        image        = "${var.docker_registry}busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R 9999:0 /storage && chmod 775 /storage && rm -rf /data/log/*.lock"]
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

      vault {
        policies = ["service-baserow"]
      }

      config {
        # entrypoint = ["sleep", "10000"]
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
        # MIGRATE_ON_STARTUP = "false"
      }
      template {
          destination = "local/config.env"
          env = true
          data = <<EOF
BASEROW_ENABLE_OTEL=true
OTEL_EXPORTER_OTLP_ENDPOINT=https://tempo-otlp-http.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=http/json
OTEL_RESOURCE_ATTRIBUTES="service.name=baserow"
OTEL_SERVICE_NAME=baserow_servicename

EMAIL_SMTP=True
EMAIL_SMTP_HOST="smtp.{{ key "site/domain" }}"
EMAIL_SMTP_PORT="5457"
EMAIL_SMTP_USE_TLS=

BASEROW_PUBLIC_URL=https://baserow.{{ key "site/domain" }}

{{with secret "kv/data/baserow-postgres"}}
DATABASE_HOST=baserow-postgres.{{ key "site/domain" }}
DATABASE_PORT=5457
DATABASE_USER={{.Data.data.postgres_username}}
DATABASE_PASSWORD={{ .Data.data.postgres_password }}
DATABASE_NAME={{.Data.data.postgres_username}}
{{ end }}

REDIS_HOST=baserow-redis.{{ key "site/domain" }}
REDIS_PORT=6379
REDIS_USER=default
REDIS_PROTOCOL=rediss

{{ with secret "kv/data/baserow-redis" }}
REDIS_PASSWORD={{.Data.data.password}}
{{ end }}
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
