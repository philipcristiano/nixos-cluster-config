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
  description = ""
}

job "minio" {
  datacenters = ["dc1"]
  type        = "system"

  update {
    max_parallel = 1
    stagger      = "60s"
  }

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "s3"
      port = "api"

      tags = [
        "prometheus",
        "traefik.enable=true",
	    "traefik.http.routers.s3.tls=true",
	    "traefik.http.routers.s3.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "api"
        interval = "10s"
        timeout  = "2s"
      }

      meta {
        metrics_path = "/minio/prometheus/metrics"
      }

    }
    service {
      name = "minio"
      port = "console"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.minio.tls=true",
	    "traefik.http.routers.minio.tls.certresolver=home",
      ]
      check {
        name     = "alive"
        type     = "tcp"
        port     = "console"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "api" {
  	    static = 9000
        to = 9000
      }
      port "console" {
        static = 9090
        to = 9090
      }

    }

    volume "storage" {
      type      = "host"
      read_only = false
      source    = "minio"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-minio"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["api", "console"]

        network_mode = "host"
        command = "server"

        args = [
          "--console-address=:9090",
        ]

      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      resources {
        cpu    = 100
        memory = 4000
        memory_max = 4000
      }

      env {
        MINIO_VOLUMES="http://nixos0{0...2}.${var.domain}:9000/storage/minio"
      }

      template {
        env = true
        data = <<EOF

{{ with secret "kv/data/minio" }}
MINIO_ROOT_USER = "{{.Data.data.ROOT_USER}}"
MINIO_ROOT_PASSWORD = "{{.Data.data.ROOT_PASSWORD}}"

MINIO_BROWSER_REDIRECT_URL = "https://minio.{{ key "site/domain"}}"

MINIO_IDENTITY_OPENID_CLAIM_NAME=scopes
MINIO_SERVER_URL="https://s3.{{ key "site/domain"}}"

MINIO_PROMETHEUS_AUTH_TYPE="public"


MINIO_IDENTITY_OPENID_CONFIG_URL="https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.IDENTITY_OPENID_CLIENT_ID}}/.well-known/openid-configuration"
MINIO_IDENTITY_OPENID_CLAIM_USERINFO="https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.IDENTITY_OPENID_CLIENT_ID}}/userinfo"

MINIO_IDENTITY_OPENID_CLIENT_ID="{{.Data.data.IDENTITY_OPENID_CLIENT_ID}}"
MINIO_IDENTITY_OPENID_CLIENT_SECRET="{{.Data.data.IDENTITY_OPENID_CLIENT_SECRET}}"
# MINIO_IDENTITY_OPENID_CLAIM_NAME="<string>"
# MINIO_IDENTITY_OPENID_CLAIM_PREFIX="<string>"
# MINIO_IDENTITY_OPENID_SCOPES="<string>"
# MINIO_IDENTITY_OPENID_REDIRECT_URI="<string>"
# MINIO_IDENTITY_OPENID_COMMENT="<string>"
{{ end }}

EOF
        destination = "secrets/file.env"
      }

    }
  }
}
