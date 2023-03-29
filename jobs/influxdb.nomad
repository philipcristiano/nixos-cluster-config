job "influxdb" {
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
      name = "influxdb"
      port = "http"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.influxdb.tls=true",
	"traefik.http.routers.influxdb.tls.certresolver=home",
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
  	to = 8086
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "influxdb"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "influxdb:2.6.1"
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/var/lib/influxdb2"
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

    }
  }
}



