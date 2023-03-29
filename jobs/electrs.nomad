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
	    "traefik.tcp.routers.electrs.tls.certresolver=home",
        "traefik.tcp.routers.electrs.entrypoints=electrs",
        "traefik.tcp.routers.electrs.rule=HostSNI(`electrs.home.cristiano.cloud`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "electrs"
        interval = "10s"
        timeout  = "2s"
      }
    }

    restart {
      attempts = 2
      interval = "3m"
      delay    = "30s"
      mode     = "delay"
    }

    network {
      port "electrs" {
  	    to = 50001
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
        image        = "busybox:latest"
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
        image = "iangregsondev/electrs:0.9.10@sha256:92dd0dd0d85d4a37eceacccdc3d2e004c92e57be27a8cff03c2906633f8f82ab"
        ports = ["electrs"]

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
daemon_rpc_addr = "bitcoin-rpc.{{ key "site/domain"}}:8882"

# The listening P2P address of bitcoind, port is usually 8333
daemon_p2p_addr = "bitcoin-p2p.{{ key "site/domain"}}:8883"

auth="{{key "credentials/electrs/bitcoind_username"}}:{{key "credentials/electrs/bitcoind_password"}}"

db_dir = "/data"

log_filters = "INFO"

EOF
      }
    }
  }
}
