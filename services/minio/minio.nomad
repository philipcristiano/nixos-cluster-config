job "minio" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "s3"
      port = "api"

      tags = [
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
        port     = "api"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "api" {
  	    to = 9000
      }
      port "console" {
        to = 9090
      }

    }
    volume "storage" {
      type            = "csi"
      source          = "minio"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-minio"]
      }

      config {
        image = "quay.io/minio/minio:RELEASE.2023-09-07T02-05-02Z"
        ports = ["api", "console"]
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
        memory = 512
      }

      env {
        MINIO_VOLUMES="/storage"
      }

      template {
        env = true
        data = <<EOF

{{ with secret "kv/data/minio" }}
MINIO_ROOT_USER = "{{.Data.data.ROOT_USER}}"
MINIO_ROOT_PASSWORD = "{{.Data.data.ROOT_PASSWORD}}"

MINIO_BROWSER_REDIRECT_URL = "https://minio.{{ key "site/domain"}}"

MINIO_IDENTITY_OPENID_CLAIM_NAME=scopes



MINIO_IDENTITY_OPENID_CONFIG_URL="https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.IDENTITY_OPENID_CLIENT_ID}}/.well-known/openid-configuration"
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
