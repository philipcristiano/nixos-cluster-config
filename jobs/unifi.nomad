job "unifi" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "unifi-command"
      port = "command"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.unifi-command.tls=true",
	"traefik.http.routers.unifi-command.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "command"
        interval = "10s"
        timeout  = "2s"
      }
    }
    service {
      name = "unifi"
      port = "https"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.unifi.tls=true",
	"traefik.http.routers.unifi.tls.certresolver=home",
	"traefik.http.services.unifi.loadbalancer.server.scheme=https",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "https"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "command" {
        static = 8080
      }
      port "https" {
  	to = 8443
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "unifi"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "jacobalberty/unifi:v7.0.23"
        ports = ["command", "https"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/unifi"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

    }
  }
}



