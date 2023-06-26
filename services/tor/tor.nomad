variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "osminogin/tor-simple:0.4.7.13"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "tor" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "tor"
      port = "tor"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.tor.entrypoints=tor",
        "traefik.tcp.routers.tor.rule=HostSNI(`*`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "tor"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "tor" {
  	    to = 9050
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-tor"]
      }

      config {
        image = var.image_id
        ports = ["tor"]
        # entrypoint = ["sleep", "10000"]

      }

      resources {
        cpu    = 50
        memory = 64
        memory_max = 256
      }

    }
  }
}



