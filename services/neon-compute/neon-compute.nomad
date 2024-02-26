
variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for compute task."
}

variable "count" {
  type        = number
  description = "The number of compute containers to run."
  default     = "1"
}

variable "name" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

job "JOB_NAME-postgres" {
  datacenters = ["dc1"]
  type        = "service"

  group "compute" {

    count = var.count

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "fail"
    }

    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "300s"
      unlimited      = true
    }

    service {
      name = "${var.name}-postgres"
      port = "pg"

      tags = [
        "traefik.enable=true",
	      "traefik.tcp.routers.${var.name}-postgres.tls=true",
	      "traefik.tcp.routers.${var.name}-postgres.tls.certresolver=home",
        "traefik.tcp.routers.${var.name}-postgres.entrypoints=postgres",
        "traefik.tcp.routers.${var.name}-postgres.rule=HostSNI(`${var.name}-postgres.${var.domain}`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "pg"
        interval = "10s"
        timeout  = "2s"
      }

      check {
        name     = "sql-select"
        type     = "script"
        task     = "app"
        interval = "30s"
        timeout  = "30s"
        command  = "sh"
        args     = ["/local/check.sh"]
      }

      check_restart {
        limit = 3
        grace = "90s"
        ignore_warnings = false
      }
    }

    network {

      port "http" {
        to = 3080
      }
      port "pg" {
        to = 55433
      }
    }

    task "pageserver-attach-tenant" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      vault {
        policies = ["service-${ var.name }-postgres"]
      }

      config {
        image = "${var.docker_registry}curlimages/curl:8.3.0-1"
        command = "curl"

        args = [
            "-v",
            "-X", "POST",
            "${PAGESERVER_ENDPOINT}/v1/tenant/${TENANT_ID}/attach"
        ]

      }

      resources {
        cpu    = 100
        memory = 128
      }

      template {
        env = true
        data = <<EOF

OTEL_EXPORTER_OTLP_ENDPOINT=https://tempo-otlp-http.{{ key "site/domain" }}:443
PAGESERVER_ENDPOINT=https://neon-pageserver-api.{{key "site/domain"}}

{{ with secret "kv/data/JOB_NAME-postgres" }}
TENANT_ID="{{.Data.data.neon_tenant_id}}"
{{ end }}

EOF
        destination = "locals/file.env"
      }
    }

    task "app" {
      driver = "docker"

      kill_timeout = "600s"

      vault {
        policies = ["service-${ var.name }-postgres"]

      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http", "pg"]
        # command = "/usr/local/bin/compute_ctl"

        args = [
            "--pgdata", "/alloc/data",
            "-C", "postgresql://cloud_admin@localhost:55433/postgres",
            "-b", "/usr/local/bin/postgres",
            "-S", "/secrets/spec.json",
        ]

      }

      resources {
        cpu    = 100
        memory = 512
      }

      template {
        env = true
        data = <<EOF

OTEL_EXPORTER_OTLP_ENDPOINT=https://tempo-otlp-http.{{ key "site/domain" }}:443
BROKER_ENDPOINT=https://neon-storage-broker.{{key "site/domain"}}

EOF
        destination = "secrets/file.env"
      }
      template {
        destination = "local/check.sh"
        data = <<EOF

set -ex
psql -p 55433 -h 127.0.0.1 -U cloud_admin postgres < /local/check.sql

EOF
      }
      template {
        destination = "local/check.sql"
        data = <<EOF
SELECT 1;
EOF
      }

      template {
        data = file("compute_spec.json")
        destination = "secrets/spec.json"
      }

    }
  }
}
