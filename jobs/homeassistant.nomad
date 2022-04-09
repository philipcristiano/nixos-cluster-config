job "homeassistant" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

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
        type     = "tcp"
        port     = "http"
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
        image = "homeassistant/home-assistant:2022.4"
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/config"
      }

      resources {
        cpu    = 2000
        memory = 1024
      }

    }
  }
}
