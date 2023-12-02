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
  default     = "jlesage/handbrake:v23.11.5"
}

job "handbrake" {
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
      name = "handbrake"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.handbrake.tls=true",
	      "traefik.http.routers.handbrake.tls.certresolver=home",
      ]

      check {
        name     = "handbrake"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
	      to = 5800
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "handbrake"
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
        args         = ["-c", "mkdir -p /storage/data && chown -R 1000:1000 /storage && chmod 775 /storage"]
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

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      env {
      }

      template {
	      destination = "/local/app.env"
        env = true
        data =  <<EOF

AUTOMATED_CONVERSION_OUTPUT_DIR=/storage/out

EOF
      }


      resources {
        cpu        = 4000
        memory     = 1024
        memory_max = 3072
      }

    }
  }
}



