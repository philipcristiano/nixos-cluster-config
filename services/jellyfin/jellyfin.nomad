variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

job "jellyfin" {
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
      name = "jellyfin"
      port = "http"

      tags = [
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.jellyfin.tls=true",
	      "traefik.http.routers.jellyfin.tls.certresolver=home",
      ]

      check {
        name     = "jellyfin"
        type     = "http"
        port     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
	      to = 8096
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "jellyfin"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "movies" {
      type            = "csi"
      source          = "movies"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "tvshows" {
      type            = "csi"
      source          = "tvshows"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "youtube_shows" {
      type            = "csi"
      source          = "yt_tvshows"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }


    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

        # sysctl = {
        #   "fs.inotify.max_user_watches" = "524288"
        # }

        mount = {
          type     = "bind"
          source   = "local/logging.json"
          target   = "/storage/config/logging.json"
          readonly = false
        }
      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      volume_mount {
        volume      = "movies"
        destination = "/movies"
      }

      volume_mount {
        volume      = "tvshows"
        destination = "/tvshows"
      }

      volume_mount {
        volume      = "youtube_shows"
        destination = "/youtube_shows"
      }

      env {
        JELLYFIN_DATA_DIR = "/storage/data"
        JELLYFIN_CACHE_DIR = "/storage/cache"
        JELLYFIN_CONFIG_DIR = "/storage/config"
      }

      template {
	destination = "/etc/local-config.yaml"
        data =  <<EOF

      EOF
      }

      template {
        destination = "local/logging.json"
        data = <<EOF

{
  "Serilog": {
    "MinimumLevel": "Debug"
  }
}
      EOF
      }

      resources {
        cpu        = 500
        memory     = 1024
        memory_max = 6000
      }

    }
  }
}



