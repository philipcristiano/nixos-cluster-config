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

job "actual" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "5m"
      delay    = "10s"
      mode     = "fail"
    }

    reschedule {
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "5m"
      unlimited      = true
    }

    service {
      name = "actual"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.actual.tls=true",
	      "traefik.http.routers.actual.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      check_restart {
        limit = 3
        grace = "90s"
        ignore_warnings = false
      }
    }

    network {
      port "http" {
  	   to = 5006
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "actual"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data"
      }

      resources {
        cpu    = 50
        memory = 192
        memory_max = 512

      }

    }
  }
}



