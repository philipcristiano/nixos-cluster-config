variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "telegraf:1.27.0"
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
      config {
        image        = var.image_id
        network_mode = "host"
        entrypoint   = ["telegraf"]

        args = [
          "-config",
          "/local/telegraf.conf",
        ]
      }

      template {
        change_mode   = "signal"
        change_signal = "SIGHUP"
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

# Read metrics from one or many prometheus clients
[[inputs.prometheus]]
  ## Scrape Services available in Consul Catalog
  [inputs.prometheus.consul]
    enabled = true
    agent = "http://consul.{{ key "site/domain" }}:8500"
    query_interval = "1m"

    {{ range services -}}
    [[inputs.prometheus.consul.query]]
      name = "{{ .Name }}"
      tag = "prometheus"
      url = {{ `'http://{{if ne .ServiceAddress ""}}{{.ServiceAddress}}{{else}}{{.Address}}{{end}}:{{.ServicePort}}{{with .ServiceMeta.metrics_path}}{{.}}{{else}}/metrics{{end}}'` }}
    {{ end }}


## Set response_timeout (default 5 seconds)

EOTC
        destination = "local/telegraf.conf"
      }

      resources {
        cpu    = 50
        memory = 64
        memory_max = 256
      }
    }
  }
}

