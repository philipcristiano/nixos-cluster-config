job "rotki" {
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
      name = "rotki"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.rotki.tls=true",
	      "traefik.http.routers.rotki.tls.certresolver=home",
      ]

      check {
        name     = "rotki"
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
      source          = "rotki"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "rotki/rotki:v1.27.1"
        ports = ["http"]

        mounts = [{
          type     = "bind"
          source   = "local"
          target   = "/config"
          readonly = true
        }]
      }

      env {
        ROTKI_ACCEPT_DOCKER_RISK = "1"
        TZ = "America/New_York"
      }

      volume_mount {
        volume      = "storage"
        destination = "/data/"
      }
      template {
	destination = "local/rotki_config.json"
        data =  <<EOF
{
   "loglevel": "debug",
   "log-dir": "/data/logs"
}

      EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }

    }
  }
}



