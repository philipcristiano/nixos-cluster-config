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

job "hello_idc" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = 2

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
      name = "hello-idc"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.hello-idc.tls=true",
        "traefik.http.routers.hello-idc.tls.certresolver=home",

	    "enable_gocast",
        "gocast_vip=192.168.110.50/32",
	    "gocast_monitor=consul",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/_health"
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

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-hello-idc"]
      }

      config {
        # entrypoint = ["sleep", "10000"]
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        args = [
          "--bind-addr", "0.0.0.0:3000",
          "--config-file", "/local/config.toml",
          "--log-level", "INFO",
        ]
      }
      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }

      template {
          destination = "local/config.toml"
          data = <<EOF

{{with secret "kv/data/hello-idc"}}

[auth]
issuer_url = "https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OAUTH_CLIENT_ID }}"
redirect_url = "https://hello-idc.{{ key "site/domain" }}/oidc/login_auth"
client_secret = "{{.Data.data.OAUTH_CLIENT_SECRET }}"
client_id = "{{.Data.data.OAUTH_CLIENT_ID }}"
key = "{{.Data.data.KEY }}"

{{end}}

EOF
      }


      resources {
        cpu    = 5
        memory = 12
        memory_max = 24
      }

    }
  }
}
