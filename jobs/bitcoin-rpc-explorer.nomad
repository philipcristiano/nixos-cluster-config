job "bitcoin-rpc-explorer" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "bitcoin-rpc-explorer"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.bitcoin-rpc-explorer.tls=true",
	      "traefik.http.routers.bitcoin-rpc-explorer.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
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
      port "http" {
  	    to = 3002
      }

    }


    task "app" {
      driver = "docker"
      kill_timeout = "600s"

      config {
        image = "runcitadel/btc-rpc-explorer:v3.2.0"
        ports = ["http"]

      }

      resources {
        cpu    = 100
        memory = 256
      }

      env {
        BTCEXP_SLOW_DEVICE_MODE = false
        BTCEXP_HOST="0.0.0.0"
      }
      template {
          env = true
          destination = "secrets/env.conf"
          data = <<EOF

BTCEXP_SECURE_SITE=true

BTCEXP_BITCOIND_HOST="bitcoin-rpc.{{ key "site/domain"}}"
BTCEXP_BITCOIND_PORT={{ key "traefik-ports/electrs" }}
BTCEXP_BITCOIND_USER={{key "credentials/bitcoin-rpc-explorer/bitcoind_username"}}
BTCEXP_BITCOIND_PASS={{key "credentials/bitcoin-rpc-explorer/bitcoind_password"}}
BTCEXP_BITCOIND_RPC_TIMEOUT=5000

BTCEXP_ADDRESS_API=electrum
BTCEXP_ELECTRUM_SERVERS=tls://electrs.{{ key "site/domain" }}:8884
DEBUG=btcexp:*

EOF
      }
    }
  }
}
