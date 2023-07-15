variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "grafana/promtail:2.8.2"
}

job "promtail-syslog" {
  datacenters = ["dc1"]
  type = "service"

  group "promtail" {
    count = 1

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

  }
}
