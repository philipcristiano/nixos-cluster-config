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
  default     = 2
}

job "et" {
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
      name = "et"
      port = "http"

      tags = [
        #"prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.et.tls=true",
	      "traefik.http.routers.et.tls.certresolver=home",
          "traefik.http.middlewares.et.retry.attempts=4",
          "traefik.http.middlewares.et.retry.initialinterval=100ms",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/_health"
        interval = "10s"
        timeout  = "2s"

        check_restart {
          limit           = 2
          grace           = "30s"
          ignore_warnings = false
        }
      }
    }

    network {
      port "http" {
  	    to = 3000
      }
    }

    task "migrate_database" {
      driver = "docker"

      vault {
        policies = ["service-et"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        entrypoint = ["/usr/local/bin/et-migrate"]
        args = [
          "--config-file",
          "/secrets/et.toml",
          "migrate",
        ]
      }

      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      template {
      	  destination = "secrets/et.toml"
          data = file("et.toml.tmpl")
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }

    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-et"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]
        args = [
          "--bind-addr", "0.0.0.0:3000",
          "--config-file", "/secrets/et.toml",
          "--log-level", "INFO",
        ]

      }

      resources {
        cpu    = 50
        memory = 128
        memory_max = 512
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }

      template {
      	  destination = "secrets/et.toml"
          data = file("et.toml.tmpl")
      }

    }
  }
}



