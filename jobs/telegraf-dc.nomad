variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "telegraf:1.27.0"
}

job "telegraf-dc" {
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
  bucket = "dc"
  organization = "{{key "credentials/telegraf-system/organization"}}"
  token = "{{key "credentials/telegraf-system/influxdb_token"}}"
[[inputs.consul]]
  ## Consul server address
  address = "consul.{{ key "site/domain" }}:8500"

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

