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
  default     = "freshrss/freshrss:1.22.0"
}

job "freshrss" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "freshrss"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.freshrss.tls=true",
	    "traefik.http.routers.freshrss.tls.certresolver=home",
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
        to = 80
      }

    }
    volume "storage" {
      type            = "csi"
      source          = "freshrss"
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
        args         = ["-c", "mkdir -p /storage/data && chown -R www-data:www-data /storage && chmod -R 774 /storage"]
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
        policies = ["service-freshrss"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

      }
      volume_mount {
        volume      = "storage"
        destination = "/var/www/FreshRSS/data"
      }

      resources {
        cpu    = 100
        memory = 256
      }

      env {
        TZ = "America/New_York"
        CRON_MIN = "1,31"
      }

      template {
          destination = "secrets/app.env"
          env = true
          data = <<EOF

{{with secret "kv/data/freshrss"}}

OIDC_ENABLED= 1
OIDC_PROVIDER_METADATA_URL= "https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OAUTH_CLIENT_ID }}"/.well-known/openid-configuration
OIDC_CLIENT_ID= "{{.Data.data.OAUTH_CLIENT_ID }}"
OIDC_CLIENT_SECRET= "{{.Data.data.OAUTH_CLIENT_SECRET }}"
OIDC_CLIENT_CRYPTO_KEY= "{{.Data.data.OIDC_CLIENT_CRYPTO_KEY }}"
OIDC_REMOTE_USER_CLAIM= preferred_username
OIDC_SCOPES=openid
OIDC_X_FORWARDED_HEADERS="X-Forwarded-Host X-Forwarded-Port X-Forwarded-Proto"
{{end}}

EOF
      }
    }
  }
}
