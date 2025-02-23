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

    volume "hostfs" {
      type      = "host"
      read_only = true
      source    = "hostfs"
    }

    task "telegraf" {
      driver = "docker"
      config {
        network_mode = "host"
        image = "${var.docker_registry}${var.image_id}"
        entrypoint   = ["telegraf"]
        args = [
          "--config-directory",
          "/local/telegraf.d",
        ]
      }

      volume_mount {
        volume      = "hostfs"
        destination = "/hostfs"
        propagation_mode = "host-to-task"
      }

      env {
        HOST_MOUNT_PREFIX="/hostfs"
        HOST_PROC="/hostfs/proc"
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

# Processor configuration to rename metric names
[[processors.regex]]
namepass = ["nomad.*"]  # Apply to metrics starting with "nomad."

# Rename the metric names by replacing periods with underscores
[[processors.regex.metric_rename]]
pattern = "\\."
replacement = "_"

[[processors.regex.metric_rename]]
pattern = "-"
replacement = "_"

EOTC
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

