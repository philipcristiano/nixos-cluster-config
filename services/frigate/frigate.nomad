variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = "ghcr.io/"
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

job "frigate" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "5m"
      delay    = "10s"
      mode     = "fail"
    }

    reschedule {
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "5m"
      unlimited      = true
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

    service {
      name = "frigate-rtsp"
      port = "rtsp"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.frigate-rtsp.entrypoints=frigate-rtsp",
        "traefik.tcp.routers.frigate-rtsp.rule=HostSNI(`*`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "rtsp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	   to = 5000
      }

      port "rtsp" {
  	   to = 8554
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
        image = "${var.docker_registry}${var.image_id}"
        # entrypoint = ["sleep", "6000"]
        ports = ["http", "rtsp"]

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

  	    devices = [
         {
           host_path = "/dev/apex_0"
           container_path = "/dev/apex_0"
         }
	    ]

      }

      volume_mount {
        volume      = "storage"
        destination = "/media"
      }

      resources {
        cpu    = 2000
        memory = 2048
      }

      env {
        LIBVA_DRIVER_NAME=radeonsi
      }

    template {
        destination = "local/config.yml"
        data = <<EOF

database:
  path: /media/frigate/frigate.db

mqtt:
  host: {{key "credentials/frigate/mqtt_host"}}
  user: {{key "credentials/frigate/mqtt_username"}}
  password: "{{key "credentials/frigate/mqtt_password"}}"

objects:
  # Optional: list of objects to track from labelmap.txt
  track:
    - person
    - bird
    - dog
    - cat
go2rtc:
  streams:

{{ range ls "credentials/frigate/cameras" }}
    {{ .Key }}: # <------ Name the camera
    - ffmpeg:{{ .Value }}

{{ end }}

cameras:
{{ range ls "credentials/frigate/cameras" }}
  {{ .Key }}: # <------ Name the camera
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/{{ .Key }}
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

motion:
  # Optional: The threshold passed to cv2.threshold to determine if a pixel is different enough to be counted as motion.
  # Increasing this value will make motion detection less sensitive and decreasing it will make motion detection more sensitive.
  # The value should be between 1 and 255.
  threshold: 15

detectors:
  coral1:
    type: edgetpu
    device: pci

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
