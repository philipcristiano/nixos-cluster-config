job "bitcoind" {
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
      name = "bitcoin-rpc"
      port = "rpc"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.bitcoin-rpc.entrypoints=bitcoin-rpc",
        "traefik.tcp.routers.bitcoin-rpc.rule=HostSNI(`*`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "rpc"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "bitcoin-p2p"
      port = "p2p"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.bitcoin-p2p.entrypoints=bitcoin-p2p",
        "traefik.tcp.routers.bitcoin-p2p.rule=HostSNI(`*`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "p2p"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "rpc" {
  	    to = 8332
      }
      port "p2p" {
  	    to = 8333
      }

    }

    volume "bitcoind" {
      type            = "csi"
      source          = "bitcoind"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "prep-disk" {
      driver = "docker"
      volume_mount {
        volume      = "bitcoind"
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

    task "bitcoind" {
      driver = "docker"
      kill_timeout = "600s"

      config {
        image = "ruimarinho/bitcoin-core:23.0"
        ports = ["rpc", "p2p"]
        args = ["-printtoconsole",
                "-rpcallowip=0.0.0.0/0",
                "-rpcbind=0.0.0.0",
                "-rpccookiefile=/alloc/data/cookiefile",
                "-conf=/local/bitcoin.conf",
        ]

        mount = {
          type     = "bind"
          source   = "local/bitcoin.conf"
          target   = "/data/bitcoin.conf"
          readonly = false
        }

      }

      volume_mount {
        volume      = "bitcoind"
        destination = "/data"
      }

      resources {
        cpu    = 1000
        memory = 6144
      }

      env {
          BITCOIN_DATA = "/data"
      }

      template {
          env = true
          destination = "local/bitcoin.conf"
          data = <<EOF

debug=rpc
txindex=1

{{ range ls "credentials/bitcoind/rpcauth" }}
rpcauth={{ .Key }}:{{ .Value }}
{{ end }}

# Whitelist peers connecting from the given IP address (e.g. 1.2.3.4) or CIDR notated network (e.g. 1.2.3.0/24). Use [permissions]address for permissions. Uses same permissions as Whitelist Bound IP Address. Can be specified multiple times. Whitelisted peers cannot be DoS banned and their transactions are always relayed, even if they are already in the mempool. Useful for a gateway node.
whitelist=192.168.102.0/24
EOF
      }

    }
  }
}
