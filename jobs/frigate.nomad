job "frigate" {
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
      name = "frigate"
      port = "http"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.frigate.tls=true",
	"traefik.http.routers.frigate.tls.certresolver=home",
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
  	to = 5000
      }

    }
    volume "storage" {
      type            = "csi"
      source          = "frigate"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "ghcr.io/blakeblackshear/frigate:0.12.0-rc2"
        ports = ["http"]

        mount {
          type     = "bind"
          source   = "local/config.yml"
          target   = "/config/config.yml"
          readonly = true
        }

        mount {
          type     = "tmpfs"
          tmpfs_options {
            size = 1000000000
          }
          target   = "/tmp/cache"
          readonly = false

        }

      }

      volume_mount {
        volume      = "storage"
        destination = "/media"
      }

      resources {
        cpu    = 2000
        memory = 2048
      }

    template {
        destination = "local/config.yml"
        data = <<EOF

mqtt:
  host: {{key "credentials/frigate/mqtt_host"}}
  user: {{key "credentials/frigate/mqtt_username"}}
  password: "{{key "credentials/frigate/mqtt_password"}}"


cameras:
{{ range ls "credentials/frigate/cameras" }}
  {{ .Key }}: # <------ Name the camera
    ffmpeg:
      inputs:
        - path: {{.Value}}  # <----- Update for your camera
          roles:
            - detect
            - record
            - rtmp
    rtmp:
      enabled: True # <-- RTMP should be disabled if your stream is not H264
    detect:
      width: 1280 # <---- update for your camera's resolution
      height: 720 # <---- update for your camera's resolution
{{ end }}

record:
  enabled: True
  retain:
    days: 7
    mode: motion
  events:
    retain:
      default: 14
      mode: active_objects

EOF
}
    }
  }
}
