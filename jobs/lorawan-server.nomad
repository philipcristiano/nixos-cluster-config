job "lorawan-server" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "lorawan-server-udp"
      port = "udp"

      tags = [
        "traefik.enable=true",
        "traefik.udp.routers.lorawan-server-udp.entrypoints=lorawan-server-udp",
        "traefik.udp.routers.lorawan-server-udp.service=lorawan-server-udp"
      ]

    }
    service {
      name = "lorawan-server-http"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.lorawan-server-http.tls=true",
        "traefik.http.routers.lorawan-server-http.tls.certresolver=home",
        "traefik.http.services.lorawan-server-http.loadbalancer.server.scheme=http",
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
      port "udp" {
        to = 1680
      }
      port "http" {
        to = 8080
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "lorawan-server"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "gotthardp/lorawan-server@sha256:9f650c987713fc105e0ac176f74ccda89287054ac3054cf3ec5db4d3b6ab13ca"
        ports = ["udp", "http"]
    hostname = "lorawan"
      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      resources {
        cpu    = 256
        memory = 512
      }

    }
  }
}



