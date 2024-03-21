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
  default     = "philipcristiano/timeline:0.0.4"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "timeline" {
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
      name = "timeline"
      port = "http"

      tags = [
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.timeline.tls=true",
	      "traefik.http.routers.timeline.tls.certresolver=home",
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
        policies = ["service-timeline"]
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
          destination = "secrets/timeline.env"
          env = true
          data = <<EOF
{{ with secret "kv/data/timeline-postgres" }}
DATABASE_URL="postgres://{{.Data.data.USER}}:{{ .Data.data.PASSWORD }}@timeline-postgres.{{ key "site/domain" }}:5457/{{.Data.data.DB}}?sslmode=verify-full"
{{ end }}

EOF
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-timeline"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]
        args = [
          "--bind-addr", "0.0.0.0:3000",
          "--config-file", "/secrets/timeline.toml",
          "--log-level", "INFO",
        ]

      }


      resources {
        cpu    = 50
        memory = 128
        memory_max = 512
      }

      template {
          destination = "secrets/timeline.toml"
          data = <<EOF

{{ with secret "kv/data/timeline-postgres" }}
database_url="postgres://{{.Data.data.postgres_username}}:{{ .Data.data.postgres_password }}@timeline-postgres.{{ key "site/domain" }}:5457/{{.Data.data.postgres_username}}?sslmode=verify-full"

{{ end }}

{{ with secret "kv/data/timeline" }}
[[integration]]
type = "PaperlessNGX"
host = "https://paperless-ngx.{{ key "site/domain" }}"
username = "timeline"
token = "f7424d802c6d5ebbfbdbdfa9a5f933616af4e12a"
{{ end }}


EOF
      }
    }
  }
}



