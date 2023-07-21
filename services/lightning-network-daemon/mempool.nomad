job "mempool" {
  datacenters = ["dc1"]
  type        = "service"

  group "mempool" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }
    service {
      name = "mempool"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.mempool.tls=true",
	      "traefik.http.routers.mempool.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "mempool-api"
      port = "api"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.mempool-api.tls=true",
	      "traefik.http.routers.mempool-api.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      mode = "bridge"
      port "http" {
  	    to = 8080
      }
      port "api" {
  	    to = 8999
      }
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "mempool/frontend:v2.5.0"
        ports = ["http"]
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "local/mempool.env"
          env = true
          data = <<EOF
FRONTEND_HTTP_PORT= "8080"
BACKEND_MAINNET_HTTP_HOST= "localhost"
BACKEND_MAINNET_HTTP_PORT= "8999"

EOF
      }

      resources {
        cpu    = 125
        memory = 150
      }
    }
    task "backend" {
      driver = "docker"

      config {
        image = "mempool/backend:v2.5.0"
        ports = ["api"]
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "local/mempool.env"
          env = true
          data = <<EOF
MEMPOOL_BACKEND="none"
CORE_RPC_HOST="bitcoin-rpc.{{ key "site/domain"}}"
CORE_RPC_PORT="{{ key "traefik-ports/bitcoin-rpc" }}"
CORE_RPC_USERNAME="{{key "credentials/mempool/bitcoind_username"}}"
CORE_RPC_PASSWORD="{{key "credentials/mempool/bitcoind_password"}}"
DATABASE_ENABLED="true"
DATABASE_HOST="mempool-mariadb.{{ key "site/domain"}}"
DATABASE_PORT="{{ key "traefik-ports/mempool-mariadb" }}"
DATABASE_DATABASE="{{key "credentials/mempool/database"}}"
DATABASE_USERNAME="{{key "credentials/mempool/database_username"}}"
DATABASE_PASSWORD="{{key "credentials/mempool/database_password"}}"
STATISTICS_ENABLED="true"

MEMPOOL_BACKEND= "electrum"
ELECTRUM_HOST= "electrs.{{ key "site/domain" }}"
ELECTRUM_PORT= "{{ key "traefik-ports/electrs" }}"
ELECTRUM_TLS_ENABLED= "true"

EOF
      }

      resources {
        cpu    = 125
        memory = 1024
        memory_max = 2048
      }

    }
  }
}
