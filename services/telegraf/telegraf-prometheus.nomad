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

job "telegraf-prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "telegraf" {

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "telegraf" {
      driver = "docker"

      vault {
        policies = ["service-telegraf-prometheus"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        network_mode = "host"
        entrypoint   = ["telegraf"]

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
        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination = "/local/telegraf.d/telegraf.conf"
        data = <<EOTC
# Adding Client class
# This should be here until https://github.com/hashicorp/nomad/pull/3882 is merged
{{ $node_class := env "node.class" }}
[global_tags]
nomad_client_class = "{{ env "node.class" }}"

[agent]
  interval = "15s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 15000
  collection_jitter = "0s"
  flush_interval = "15s"
  flush_jitter = "3s"
  precision = "1ms"
  debug = true
  quiet = false
  hostname = ""
  omit_hostname = false

# Read metrics from one or many prometheus clients
[[inputs.prometheus]]
  ## Scrape Services available in Consul Catalog
  metric_version = 1

  [inputs.prometheus.consul]
    enabled = true
    agent = "http://consul.{{ key "site/domain" }}:8500"
    query_interval = "1m"

    {{ range services -}}
    [[inputs.prometheus.consul.query]]
      name = "{{ .Name }}"
      tag = "prometheus"
      url = {{ `'http://{{if ne .ServiceAddress ""}}{{.ServiceAddress}}{{else}}{{.Address}}{{end}}:{{with .ServiceMeta.metrics_port}}{{.}}{{else}}{{.ServicePort}}{{end}}{{with .ServiceMeta.metrics_path}}{{.}}{{else}}/metrics{{end}}'` }}
    {{ end }}


## Set response_timeout (default 5 seconds)

EOTC
      }

      resources {
        cpu    = 50
        memory = 128
        memory_max = 512
      }
    }
  }
}

