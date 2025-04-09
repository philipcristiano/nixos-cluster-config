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

job "mathesar" {
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
      name = "mathesar"
      port = "http"

      tags = [
        #"prometheus",
        "traefik.enable=true",
	    "traefik.http.routers.mathesar.tls=true",
	    "traefik.http.routers.mathesar.tls.certresolver=home",
      ]

      //check {
      //  name     = "alive"
      //  type     = "http"
      //  port     = "http"
      //  path     = "/"
      //  interval = "10s"
      //  timeout  = "2s"

      //  check_restart {
      //    limit           = 2
      //    grace           = "90s"
      //    ignore_warnings = false
      //  }
      //}
    }

    network {
      port "http" {
  	    to = 8000
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-mathesar"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

      }

      resources {
        cpu    = 50
        memory = 512
        memory_max = 512
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }

      template {
      	  destination = "secrets/mathesar.env"
          env = true
          data = file("mathesar.env.tmpl")
      }

    }
  }
}



