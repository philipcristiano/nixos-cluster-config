variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "outlinewiki/outline:0.71.0"
}

job "outline" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

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
      name = "outline"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.outline.tls=true",
	      "traefik.http.routers.outline.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	    to = 3000
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-outline"]
      }

      config {
        # entrypoint = ["sleep", "10000"]
        image = var.image_id
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

DATABASE_URL=postgres://{{ key "credentials/outline-postgres/USER" }}:{{ key "credentials/outline-postgres/PASSWORD" }}@outline-postgres.{{ key "site/domain" }}:{{ key "traefik-ports/outline-postgres" }}/{{ key "credentials/outline-postgres/DB" }}?sslmode=disable

REDIS_URL=redis://default:{{ key "credentials/outline-redis/password" }}@outline-redis.{{ key "site/domain" }}:{{ key "traefik-ports/outline-redis" }}

AWS_REGION=minio
AWS_S3_FORCE_PATH_STYLE=false
AWS_S3_UPLOAD_BUCKET_NAME=outline
AWS_S3_UPLOAD_BUCKET_URL=https://minio.{{ key "site/domain"}}
AWS_S3_UPLOAD_MAX_SIZE=26214400

{{with secret "kv/data/outline"}}
AWS_ACCESS_KEY_ID={{.Data.data.STORAGE_ACCESS_KEY}}
AWS_SECRET_ACCESS_KEY={{.Data.data.STORAGE_SECRET_KEY}}
UTILS_SECRET={{.Data.data.UTILS_SECRET }}
SECRET_KEY={{.Data.data.SECRET_KEY }}

OIDC_CLIENT_ID= {{.Data.data.OAUTH_CLIENT_ID }}
OIDC_CLIENT_SECRET= {{.Data.data.OAUTH_CLIENT_SECRET }}
OIDC_AUTH_URI= https://kanidm.{{key "site/domain"}}/ui/oauth2
OIDC_TOKEN_URI=https://kanidm.{{key "site/domain"}}/oauth2/token
OIDC_USERINFO_URI= https://kanidm.{{key "site/domain"}}/oauth2/openid/{{.Data.data.OAUTH_CLIENT_ID }}/userinfo
OIDC_USERNAME_CLAIM= preferred_username
OIDC_DISPLAY_NAME= OpenID

{{end}}

URL=https://outline.{{ key "site/domain"}}
PORT=3000
FORCE_HTTPS=false

SMTP_HOST="smtp.{{ key "site/domain" }}"
SMTP_PORT="{{ key "traefik-ports/smtp" }}"
SMTP_SECURE=false
SMTP_FROM_EMAIL="Outline <outline@{{ key "site/domain" }}>"


EOF
      }


      resources {
        cpu    = 50
        memory = 512
        memory_max = 1024
      }

    }
  }
}
