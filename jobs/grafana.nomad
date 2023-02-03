job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "grafana"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.grafana.tls=true",
	    "traefik.http.routers.grafana.tls.certresolver=home",
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
  	to = 3000
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "grafana"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "grafana/grafana-oss:9.3.2"
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/var/lib/grafana"
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}
