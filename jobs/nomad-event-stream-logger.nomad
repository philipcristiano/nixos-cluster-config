variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "curlimages/curl:8.00.1"
}

job "nomad-event-stream-logger" {
  datacenters = ["dc1"]

  group "app" {
    count = 1

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    task "curl" {
      driver = "docker"
      config {
        network_mode = "host"
        image        = var.image_id
        args         = [
          "-s",
          "-v",
          "http://127.0.0.1:4646/v1/event/stream",
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }

    }

  }
}

