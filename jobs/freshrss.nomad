job "freshrss" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "freshrss"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.freshrss.tls=true",
	      "traefik.http.routers.freshrss.tls.certresolver=home",
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
        to = 80
      }

    }
    volume "storage" {
      type            = "csi"
      source          = "freshrss"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "prep-disk" {
      driver = "docker"
      volume_mount {
        volume      = "storage"
        destination = "/storage"
        read_only   = false
      }
      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R www-data:www-data /storage && chmod -R 774 /storage"]
      }
      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }


    task "app" {
      driver = "docker"

      config {
        image = "freshrss/freshrss:edge@sha256:008e478f5e5b5da599266ad373d213bc1f31afd186628cdecd1f46b1c0568fce"
        ports = ["http"]

      }
      volume_mount {
        volume      = "storage"
        destination = "/var/www/FreshRSS/data"
      }

      resources {
        cpu    = 100
        memory = 512
      }

      env {
        TZ = "America/New_York"
        CRON_MIN = "1,31"
      }

    }
  }
}
