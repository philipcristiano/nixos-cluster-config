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
  default     = "grafana/mimir:2.9.0"
}

job "mimir" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "mimir"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.mimir.tls=true",
	      "traefik.http.routers.mimir.tls.certresolver=home",
      ]

      check {
        name     = "mimir"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
	      to = 8080
      }
      port "grpc" {
	      to = 9095
      }
    }

    ephemeral_disk {
      # Used to store index, cache, WAL
      # Nomad will try to preserve the disk between job updates
      size   = 1000
      sticky = true
    }

    task "app" {
      driver = "docker"
      kill_timeout = "180s"

      vault {
        policies = ["service-mimir"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http", "grpc"]

        args = [
          "-config.file", "secrets/config.yaml",
          "-config.expand-env=true",
        ]

      }

      # volume_mount {
      #   volume      = "storage"
      #   destination = "/storage/"
      # }

      template {
	      destination = "secrets/aws.env"
        env = true
        data =  <<EOF

{{ with secret "kv/data/mimir" }}
AWS_ACCESS_KEY_ID={{.Data.data.ACCESS_KEY}}
AWS_SECRET_ACCESS_KEY={{.Data.data.SECRET_KEY}}
{{ end }}
EOF
      }

      template {
	      destination = "secrets/config.yaml"
        data = file("./mimir.yaml")
      }

      resources {
        cpu    = 100
        memory = 256
        memory_max = 1024
      }

    }
  }
}



