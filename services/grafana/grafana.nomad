variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "grafana/grafana-oss:9.5.2"
}

job "grafana" {
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
      name = "grafana"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.grafana.tls=true",
	    "traefik.http.routers.grafana.tls.certresolver=home",
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

    volume "storage" {
      type            = "csi"
      source          = "grafana"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-grafana"]
      }

      config {
        image = var.image_id
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/var/lib/grafana"
      }

      template {
          destination = "local/app.env"
          env = true
          data = <<EOF
GF_SERVER_ROOT_URL="https://grafana.{{ key "site/domain" }}"
GF_RENDERING_SERVER_URL="https://grafana-image-renderer.{{ key "site/domain" }}/render"
GF_RENDERING_CALLBACK_URL="https://grafana.{{ key "site/domain" }}"
GF_LOG_FILTERS="rendering:debug"

{{with secret "kv/data/grafana"}}
GF_RENDERING_RENDERER_TOKEN="{{.Data.data.image_renderer_auth_token}}"

GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP = true
GF_AUTH_GENERIC_OAUTH_AUTO_LOGIN = false
GF_AUTH_GENERIC_OAUTH_CLIENT_ID = {{.Data.data.OAUTH_CLIENT_ID }}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = {{.Data.data.OAUTH_CLIENT_SECRET }}
GF_AUTH_GENERIC_OAUTH_SCOPES = openid email profile
GF_AUTH_GENERIC_OAUTH_AUTH_URL = https://kanidm.{{ key "site/domain"}}/ui/oauth2
GF_AUTH_GENERIC_OAUTH_TOKEN_URL = https://kanidm.{{ key "site/domain"}}/oauth2/token
GF_AUTH_GENERIC_OAUTH_API_URL = https://kanidm.{{ key "site/domain"}}/oauth2/openid/grafana/userinfo
GF_AUTH_GENERIC_OAUTH_USE_PKCE = true

{{end}}


EOF
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}
