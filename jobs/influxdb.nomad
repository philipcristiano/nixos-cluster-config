job "influxdb" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

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
        image = "quay.io/influxdb/influxdb:2.1.1"
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/root/.influxdbv2"
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}



