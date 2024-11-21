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
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "grist" {
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
      name = "grist"
      port = "http"

      tags = [
        #"prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.grist.tls=true",
	      "traefik.http.routers.grist.tls.certresolver=home",
      ]

      # check {
      #   name     = "alive"
      #   type     = "http"
      #   port     = "http"
      #   path     = "/"
      #   interval = "10s"
      #   timeout  = "2s"

      #   check_restart {
      #     limit           = 2
      #     grace           = "30s"
      #     ignore_warnings = false
      #   }
      # }
    }

    network {
      port "http" {
  	    to = 8484
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-grist"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]

      }

      resources {
        cpu    = 50
        memory = 256
        memory_max = 256
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }

      template {
      	  destination = "secrets/grist.env"
          env = true
          data = file("grist.env.tmpl")
      }

    }
  }
}



