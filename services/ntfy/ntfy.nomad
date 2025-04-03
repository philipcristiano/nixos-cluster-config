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
  default     = ""
}

job "ntfy" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {


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

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }


    service {
      name = "ntfy"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.ntfy.tls=true",
	      "traefik.http.routers.ntfy.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
  	    to = 80
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-ntfy"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

        args = ["serve",
                "--config", "/local/config.yml"
        ]
      }

      resources {
        cpu    = 100
        memory = 32
        memory_max = 128
      }

      template {
      	  destination = "local/config.yml"
          data = file("config.yml")
      }

    }
  }
}



