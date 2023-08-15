variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "philipcristiano/hello_idc:0.0.1"
}

job "hello_idc" {
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
      name = "hello-idc"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.hello-idc.tls=true",
	      "traefik.http.routers.hello-idc.tls.certresolver=home",
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
        image = var.image_id
        ports = ["http"]
        args = [
        "--bind-addr", "0.0.0.0:3000",
        "--config-file", "/local/config.toml"]
      }

      template {
          destination = "local/config.toml"
          data = <<EOF

{{with secret "kv/data/hello-idc"}}

[auth]
issuer_url = "https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OAUTH_CLIENT_ID }}"
redirect_url = "https://hello-idc.{{ key "site/domain" }}/login_auth"
client_secret = "{{.Data.data.OAUTH_CLIENT_SECRET }}"
client_id = "{{.Data.data.OAUTH_CLIENT_ID }}"

{{end}}

EOF
      }


      resources {
        cpu    = 5
        memory = 16
        memory_max = 64
      }

    }
  }
}
