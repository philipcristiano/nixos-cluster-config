variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "awesometechnologies/synapse-admin:0.8.7"
}

job "synapse-admin" {
  datacenters = ["dc1"]
  type        = "service"

  group "synapse-admin" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    network {
      port "http" {
  	    to = 80
      }
    }

    service {
      name = "synapse-admin"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.synapse-admin.tls=true",
        "traefik.http.routers.synapse-admin.entrypoints=http,https",
	      "traefik.http.routers.synapse-admin.tls.certresolver=home",
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

    task "app" {
      driver = "docker"

      config {
        image = var.image_id
        ports = ["http"]
      }

      template {
          destination = "local/app.env"
          env = true
          data = <<EOF

REACT_APP_SERVER="https://matrix.{{ key "site/domain" }}"

EOF
      }

      resources {
        cpu    = 10
        memory = 24
        memory_max = 128
      }

    }
  }
}
