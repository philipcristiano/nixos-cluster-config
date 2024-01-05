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

job "telegraf-influxdb-input" {
  datacenters = ["dc1"]
  type        = "service"

  group "telegraf" {

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    service {
      name = "influxdb-write"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.influxdb-write.tls=true",
	    "traefik.http.routers.influxdb-write.tls.certresolver=home",
      ]

      check {
        name     = "influxdb-input"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "influxdb"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.influxdb.tls=true",
	    "traefik.http.routers.influxdb.tls.certresolver=home",
      ]

      check {
        name     = "influxdb-input"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
	      to = 8080
      }
    }

    task "telegraf" {
      driver = "docker"
      config {
        image = "${var.docker_registry}${var.image_id}"
        entrypoint   = ["telegraf"]
        ports = ["http"]
        args = [
          "--config-directory",
          "/local/telegraf.d",
        ]
      }

      template {
      	  destination = "/local/telegraf.d/http-output.conf"
          data = file("telegraf.httpoutput.conf")
      }

      template {
        destination = "/local/telegraf.d/telegraf.conf"
        data = <<EOTC
# Adding Client class
# This should be here until https://github.com/hashicorp/nomad/pull/3882 is merged
{{ $node_class := env "node.class" }}
[global_tags]
nomad_client_class = "{{ env "node.class" }}"

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "3s"
  precision = ""
  debug = false
  quiet = false
  hostname = ""
  omit_hostname = false

[[inputs.http_listener_v2]]
  ## Address and port to host HTTP listener on
  service_address = ":8080"
  data_format = "influx"
  paths = ["/write", "/api/v2/write"]

[[outputs.http]]
  ## URL is the address to send metrics to
  url = "https://mimir.{{ key "site/domain" }}/api/v1/push"

  ## Optional TLS Config
  # tls_ca = "/etc/telegraf/ca.pem"
  # tls_cert = "/etc/telegraf/cert.pem"
  # tls_key = "/etc/telegraf/key.pem"

  ## Data format to output.
  data_format = "prometheusremotewrite"

  [outputs.http.headers]
     Content-Type = "application/x-protobuf"
     Content-Encoding = "snappy"
     X-Prometheus-Remote-Write-Version = "0.1.0"


EOTC
      }

      resources {
        cpu    = 50
        memory = 64
        memory_max = 256
      }
    }
  }
}

