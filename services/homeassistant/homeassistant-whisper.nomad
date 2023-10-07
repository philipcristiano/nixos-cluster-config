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
  default     = "rhasspy/wyoming-whisper:1.0.0"
}

job "homeassistant-whisper" {
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
      name = "homeassistant-whisper"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.homeassistant-whisper.entrypoints=homeassistant-whisper",
        "traefik.tcp.routers.homeassistant-whisper.rule=HostSNI(`*`)",
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
  	    to = 10300
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "homeassistant-whisper"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

        args = [
          "--model",
          "tiny-int8",
          "--language",
          "en",
        ]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data"
      }

      resources {
        cpu    = 250
        memory = 1024
        memory_max = 2048
      }

    }
  }
}
