variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "telegraf:1.27.0"
}

job "telegraf-system" {
  datacenters = ["dc1"]
  type        = "system"

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
        network_mode = "host"
        image        = var.image_id
        force_pull   = true
        entrypoint   = ["telegraf"]
        args = [
          "-config",
          "/local/telegraf.conf",
        ]
      }

      template {
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

[[outputs.influxdb_v2]]
  urls = ["https://influxdb.{{ key "site/domain" }}"]
  bucket = "host"
  organization = "{{key "credentials/telegraf-system/organization"}}"
  token = "{{key "credentials/telegraf-system/influxdb_token"}}"

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

[[inputs.cpu]]
[[inputs.disk]]
[[inputs.mem]]
[[inputs.system]]
[[inputs.temp]]

[[inputs.nomad]]
## URL for the Nomad agent
url = "http://127.0.0.1:4646"

## Set response_timeout (default 5 seconds)
response_timeout = "5s"
EOTC
        destination = "local/telegraf.conf"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

