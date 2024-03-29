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
}

job "electrs" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "electrs"
      port = "electrs"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.electrs.entrypoints=electrs",
        "traefik.tcp.routers.electrs.rule=HostSNI(`*`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "electrs"
        interval = "10s"
        timeout  = "2s"
      }
    }
    service {
      name = "electrs-prometheus"
      port = "prometheus"

      tags = [
        "prometheus",
      ]

      check {
        name     = "prometheus"
        type     = "tcp"
        port     = "prometheus"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "electrs" {
  	    to = 50001
      }

      port "prometheus" {
  	    to = 4224
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "electrs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }


    task "prep-disk" {
      driver = "docker"
      volume_mount {
        volume      = "storage"
        destination = "/storage"
        read_only   = false
      }
      config {
        image        = "${var.docker_registry}busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R 1000:0 /storage && chmod 775 /storage"]
      }
      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "electrs" {
      driver = "docker"
      kill_timeout = "600s"

      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["electrs", "prometheus"]

        #entrypoint = ["sleep", "10000"]
        args = [
            "--conf=/local/electrs.conf",
        ]

      }

      volume_mount {
        volume      = "storage"
        destination = "/data"
      }

      resources {
        cpu    = 100
        memory = 4000
      }

      env {
          ELECTRS_ELECTRUM_RPC_ADDR="0.0.0.0:50001"
      }
      template {
          env = true
          destination = "local/electrs.conf"
          data = <<EOF

# The listening RPC address of bitcoind, port is usually 8332
daemon_rpc_addr = "bitcoin-rpc.{{ key "site/domain"}}:{{ key "traefik-ports/bitcoin-rpc" }}"

# The listening P2P address of bitcoind, port is usually 8333
daemon_p2p_addr = "bitcoin-p2p.{{ key "site/domain"}}:{{ key "traefik-ports/bitcoin-p2p" }}"

monitoring_addr = "0.0.0.0:{{ env "NOMAD_PORT_prometheus" }}"

auth="{{key "credentials/electrs/bitcoind_username"}}:{{key "credentials/electrs/bitcoind_password"}}"

db_dir = "/data"

log_filters = "INFO"

EOF
      }
    }
  }
}
