job "zwavejs2mqtt" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "zwavejs2mqtt"
      port = "http"

      tags = [
        "traefik.enable=true",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "zwavejs2mqtt"
      port = "websocket"

      tags = [
        "traefik.enable=true",
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
  	to = 8091
      }
      port "websocket" {
        to = 3000
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "zwavejs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "zwavejs/zwavejs2mqtt:6.2.0"
        ports = ["http", "websocket"]

      }

      volume_mount {
        volume      = "storage"
        destination = "/usr/src/app/store"
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}



