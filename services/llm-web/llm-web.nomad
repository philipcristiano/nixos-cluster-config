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
  description = "The docker image"
}

job "llm-web" {
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
      name = "llm-web"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.llm-web.tls=true",
	    "traefik.http.routers.llm-web.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"

      }
    }

    network {
      port "http" {
  	    to = 8080
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "llm"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "ollama" {
      type            = "csi"
      source          = "ollama"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-llm-web"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        args  = []

      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      volume_mount {
        volume      = "ollama"
        destination = "/root/.ollama"
      }

      resources {
        cpu    = 4000
        memory = 15000
        memory_max = 20000
      }
      env {
          DATA_DIR = "/storage"
      }

      template {
          destination = "secret/app.env"
          env = true
          data = <<EOF

WEBUI_SESSION_COOKIE_SECURE=true
WEBUI_SESSION_COOKIE_SAME_SITE=strict
{{with secret "kv/data/llm-web"}}
WEBUI_SECRET_KEY="{{.Data.data.WEBUI_SECRET_KEY }}"

ENABLE_OAUTH_SIGNUP=true
OPENID_PROVIDER_URL = "https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OAUTH_CLIENT_ID }}/.well-known/openid-configuration"
redirect_url = "https://llm-web.{{ key "site/domain" }}/oauth/oidc/callback"
OAUTH_CLIENT_SECRET = "{{.Data.data.OAUTH_CLIENT_SECRET }}"
OAUTH_CLIENT_ID = "{{.Data.data.OAUTH_CLIENT_ID }}"

{{end}}

EOF
      }
    }
  }
}
