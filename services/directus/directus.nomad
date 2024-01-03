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
  default     = "directus/directus:10.8.3"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "directus" {
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
      name = "directus"
      port = "http"

      tags = [
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.directus.tls=true",
	      "traefik.http.routers.directus.tls.certresolver=home",
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
  	    to = 8055
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-directus"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]

      }


      resources {
        cpu    = 50
        memory = 256
        memory_max = 512
      }

      template {
          destination = "secrets/directus.env"
          env = true
          data = <<EOF

PUBLIC_URL=https://directus.{{ key "site/domain" }}

{{ with secret "kv/data/directus" }}

KEY={{.Data.data.KEY }}
SECRET={{.Data.data.SECRET }}
AUTH_PROVIDERS=kanidm
AUTH_KANIDM_DRIVER=openid
AUTH_KANIDM_CLIENT_ID={{.Data.data.OIDC_CLIENT_ID }}
AUTH_KANIDM_CLIENT_SECRET={{.Data.data.OIDC_CLIENT_SECRET }}
AUTH_KANIDM_ISSUER_URL=https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OIDC_CLIENT_ID }}/.well-known/openid-configuration

AUTH_KANIDM_IDENTIFIER_KEY=sub
AUTH_KANIDM_ALLOW_PUBLIC_REGISTRATION=true
AUTH_KANIDM_DEFAULT_ROLE_ID={{.Data.data.DEFAULT_ROLE_ID }}

STORAGE_LOCATIONS=minio
STORAGE_MINIO_DRIVER=s3
STORAGE_MINIO_KEY={{.Data.data.S3_ACCESS_KEY }}
STORAGE_MINIO_SECRET={{.Data.data.S3_SECRET_KEY }}
STORAGE_MINIO_BUCKET={{.Data.data.S3_BUCKET }}
STORAGE_MINIO_REGION=minio
STORAGE_MINIO_ENDPOINT=https://s3.{{ key "site/domain"}}
STORAGE_MINIO_FORCE_PATH_STYLE=true

{{ end }}


{{ with secret "kv/data/directus-postgres" }}
DB_CLIENT="pg"

DB_CONNECTION_STRING=postgresql://{{.Data.data.postgres_username}}:{{ .Data.data.postgres_password }}@directus-postgres.{{ key "site/domain" }}:5457/{{.Data.data.postgres_username}}?sslmode=verify-full

{{ end }}


EOF
      }
    }
  }
}



