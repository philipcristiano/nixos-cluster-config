variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "zwavejs/zwave-js-ui:8.18.0"
}

job "zwavejs2mqtt" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 1
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }

    constraint {
      attribute = "${attr.unique.hostname}"
      value     = "nixos02"
    }

    service {
      name = "zwavejs"
      port = "http"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.zwavejs.tls=true",
	"traefik.http.routers.zwavejs.tls.certresolver=home",
	#"traefik.http.routers.zwavejs.entrypoints=http,https",
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
      name = "zwavejs-websocket"
      port = "websocket"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.zwavejs-websocket.tls=true",
	"traefik.http.routers.zwavejs-websocket.tls.certresolver=home",
	#"traefik.http.routers.zwavejs-websocket.entrypoints=http,https",
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
  	   to = 8091
      }
      port "websocket" {
	     to = 3000
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "zwavejs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = var.image_id
        ports = ["http", "websocket"]
  	devices = [
         {
           host_path = "/dev/ttyACM0"
           container_path = "/dev/ttyACM0"
         }
	]

      }

      volume_mount {
        volume      = "storage"
        destination = "/usr/src/app/store"
      }

      resources {
        cpu    = 500
        memory = 256

        # device "usb" {
        #    constraint {
        #     attribute = "${device.vendor_id}"
        #     value = "0658"
        #    }
        # }

      }

    }
  }
}



