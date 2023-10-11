variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "philipcristiano/gocast:sha-a00e6fd"
}

job "gocast" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "system"

  update {
    max_parallel = 1
    stagger      = "300s"
  }

  group "gocast" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 7001
      }
    }

    service {
      name = "gocast"

      check {
        name     = "alive-http"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "app" {
      driver = "docker"

      env {
        CONSUL_NODE = "${node.unique.name}"
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        network_mode = "host"

	    args = ["-config=/local/config.yaml", "-logtostderr", "-v=2"]

	    cap_add = ["net_admin"]

      }

      template {
        destination = "local/config.yaml"
        data = <<EOF
agent:
  # http server listen addr
  listen_addr: :7001
  # Interval for health check
  monitor_interval: 10s
  # Time to flush out inactive apps
  cleanup_timer: 15m
  # Consul api addr for dynamic discovery
  consul_addr: http://localhost:8500/v1
  # interval to query consul for app discovery
  consul_query_interval: 1m

bgp:
  local_as: 65001
  remote_as: 65000
  peer_ip: 192.168.102.1
  communities:
    - 100:100
  origin: igp
EOF

      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
