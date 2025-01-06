variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for compute task."
}

variable "count" {
  type        = number
  description = "The number of compute containers to run."
  default     = "1"
}

variable "domain" {
  type        = string
  description = "Domain name of this instance of rmqtt"
}

job "rmqtt" {
  datacenters = ["dc1"]
  type        = "service"

  group "compute" {

    count = var.count

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "rmqtt"
      port = "mqtt"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.rmqtt.entrypoints=mqtt",
        "traefik.tcp.routers.rmqtt.rule=HostSNI(`*`)",
      ]

      check {
        name     = "rmqtt-mqtt"
        type     = "tcp"
        port     = "mqtt"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {

      port "mqtt" {
        to = 1883
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-rmqtt"]

      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["mqtt"]
        args = ["-f", "/local/rmqtt.toml"]

      }

      resources {
        cpu    = 50
        memory = 256
        memory_max = 256
      }

      template {
        destination = "local/rmqtt.toml"
        data = file("rmqtt.toml")
      }

      template {
        destination = "secrets/plugins/rmqtt-acl.toml"
        data = file("rmqtt-acl.toml")
      }

      template {
        destination = "secrets/plugins/rmqtt-http-api.toml"
        data = file("rmqtt-http-api.toml")
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }
    }
  }
}
