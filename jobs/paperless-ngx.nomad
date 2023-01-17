job "paperless-ngx" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "paperless-ngx"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.paperless-ngx.tls=true",
	      "traefik.http.routers.paperless-ngx.tls.certresolver=home",
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
  	    to = 8000
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "paperless-ngx"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "paperlessngx/paperless-ngx:1.11"
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data/paperless"
      }

      resources {
        cpu    = 1000
        memory = 512
      }

      env {
          PAPERLESS_DATA_DIR = "/data/paperless/data"
          PAPERLESS_CONSUMPTION_DIR = "/data/paperless/consume"
          PAPERLESS_MEDIA_ROOT = "/data/paperless/data"
          PAPERLESS_CONSUMER_POLLING = 10
          PAPERLESS_DBENGINE = "sqlite"
          PAPERLESS_REDIS = "redis://redis-paperless-ngx.home.cristiano.cloud:6380"
      }

    }
  }
}
