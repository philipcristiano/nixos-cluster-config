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

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 2
}

job "et" {
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
      name = "et"
      port = "http"

      tags = [
        #"prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.et.tls=true",
	      "traefik.http.routers.et.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"

        check_restart {
          limit           = 2
          grace           = "30s"
          ignore_warnings = false
        }
      }
    }

    network {
      port "http" {
  	    to = 3000
      }
    }

    task "migrate_database" {
      driver = "docker"

      vault {
        policies = ["service-et"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        entrypoint = ["/atlas"]
        args = [
          "schema",
          "apply",
          "-c=file://atlas.hcl",
          "--env=local",
          "--auto-approve"
        ]

      }
      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      template {
          destination = "secrets/et.env"
          env = true
          data = <<EOF
{{ with secret "kv/data/et-postgres" }}
DATABASE_URL="postgres://{{.Data.data.USER}}:{{ .Data.data.PASSWORD }}@et-postgres.{{ key "site/domain" }}:5457/{{.Data.data.DB}}?sslmode=verify-full"
{{ end }}

EOF
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-et"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]
        args = [
          "--bind-addr", "0.0.0.0:3000",
          "--config-file", "/secrets/et.toml",
          "--log-level", "INFO",
        ]

      }


      resources {
        cpu    = 50
        memory = 128
        memory_max = 512
      }

      template {
          destination = "local/otel.env"
          env = true
          data = <<EOF
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://tempo-otlp-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_SERVICE_NAME={{ env "NOMAD_JOB_NAME" }}

EOF
      }

      template {
          destination = "secrets/et.toml"
          data = <<EOF

{{ with secret "kv/data/et-postgres" }}
database_url="postgres://{{.Data.data.USER}}:{{ .Data.data.PASSWORD }}@et-postgres.{{ key "site/domain" }}:5457/{{.Data.data.DB}}?sslmode=verify-full"

{{ end }}

{{ with secret "kv/data/et" }}

[auth]
issuer_url = "https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OAUTH_CLIENT_ID }}"
redirect_url = "https://et.{{ key "site/domain" }}/oidc/login_auth"
client_secret = "{{.Data.data.OAUTH_CLIENT_SECRET }}"
client_id = "{{.Data.data.OAUTH_CLIENT_ID }}"
key = "{{.Data.data.KEY }}"
{{ end }}


EOF
      }
    }
  }
}



