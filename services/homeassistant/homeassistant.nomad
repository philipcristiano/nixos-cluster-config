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
  default     = "homeassistant/home-assistant:2023.12.0"
}

job "homeassistant" {
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
      name = "homeassistant"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.homeassistant.tls=true",
	    "traefik.http.routers.homeassistant.tls.certresolver=home",
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
  	    to = 8123
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "homeassistant"
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
        destination = "/config"
      }

      resources {
        cpu    = 250
        memory = 1024
      }

    }
  }
}
