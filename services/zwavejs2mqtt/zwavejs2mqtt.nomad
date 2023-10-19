variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "zwavejs/zwave-js-ui:9.2.2"
}

job "zwavejs2mqtt" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 1
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
      name = "zwavejs"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.zwavejs.tls=true",
	    "traefik.http.routers.zwavejs.tls.certresolver=home",
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
        image = "${var.docker_registry}${var.image_id}"
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
        cpu    = 50
        memory = 192
        memory_max = 512

        # device "usb" {
        #   constraint {
        #     attribute = "${device.vendor}"
        #     value = "1624"
        #   }
        # }

      }

    }
  }
}



