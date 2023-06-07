variable "ip" {
  type        = string
  description = "The IP address for the floating IP/binding."
  default     = "192.168.102.50"
}

job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    ephemeral_disk {
      size    = 500
      sticky  = true
    }

    network {
      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }

      port "folio-postgres" {
        static = 5433
      }

      port "mattermost-postgres" {
        static = 5435
      }

      port "baserow-postgres" {
        static = 5436
      }

      port "paperless-redis" {
        static = 6380
      }

      port "baserow-redis" {
        static = 6381
      }

      port "api" {
        static = 8081
      }

      port "frigate-rtsp" {
        static = 8554
      }

      port "bitcoin-rpc" {
        static = 8882
      }

      port "bitcoin-p2p-tcp" {
        static = 8883
      }

      port "electrs-tcp" {
        static = 8884
      }

      port "lorawan-server-udp" {
        static = 1700
      }

    }

    service {
      name = "traefik"

      tags = [
	    "enable_gocast",
        "gocast_vip=192.168.102.50/32",
	    "gocast_monitor=consul",
      ]

      check {
        name     = "alive-api"
        type     = "http"
        port     = "api"
        # protocol = "https"
        path     = "/dashboard"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.0"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }
      template {
	env = true
        destination = "secrets/file.env"
        data = <<EOH
DNSIMPLE_OAUTH_TOKEN="{{ key "credentials/traefik/DNSIMPLE_OAUTH_TOKEN"}}"
	EOH
      }

      template {
        data = <<EOF
[entryPoints]

    ## PUBLIC ACCESS ENTRYPOINTS

    address = ":3080"
      [entryPoints.http-public.http.redirections]
        [entryPoints.http-public.http.redirections.entryPoint]
          to = "https-public"
          scheme = "https"
          permanent = true
    [entryPoints.https-public]
    address = ":3443"

    ## INTERNAL ACCESS ENTRYPOINTS

    [entryPoints.http]
    asDefault = "true"
    address = ":80"
      [entryPoints.http.http.redirections]
        [entryPoints.http.http.redirections.entryPoint]
          to = "https"
          scheme = "https"
          permanent = true
    [entryPoints.https]
    asDefault = "true"
    address = ":443"
    [entryPoints.lorawan-server-udp]
    address = ":1700/udp"
      [entryPoints.lorawan-server-udp.udp]
      timeout= "120s"
    [entryPoints.mqtt]
    address = ":1883"
    [entryPoints.folio-postgres]
    address = ":5433"
    [entryPoints.mempool-mariadb]
    address = ":5434"
    [entryPoints.mattermost-postgres]
    address = ":5435"
    [entryPoints.baserow-postgres]
    address = ":5436"
    [entryPoints.redis-paperless-ngx]
    address = ":6380"
    [entryPoints.baserow-redis]
    address = ":6381"
    [entryPoints.frigate-rtsp]
    address = ":8554"
    [entryPoints.traefik]
    address = ":8081"
    [entryPoints.bitcoin-rpc]
    address = ":8882"
    [entryPoints.bitcoin-p2p]
    address = ":8883"
    [entryPoints.electrs]
    address = ":8884"

# Consul derived ports
{{range ls "traefik-ports/"}}
    [entryPoints.{{.Key}}]
    address = ":{{.Value}}"
{{end}}

[serversTransport]
  insecureSkipVerify = true
[api]
    dashboard = true
    insecure  = true
[log]
  format = "json"
  level = "INFO"
[accessLog]
  format = "json"

  [accessLog.filters]
    statusCodes = ["300-302", "400-499"]
    retryAttempts = true
[tracing]
  [tracing.openTelemetry]
    address = "otel-grpc.{{ key "site/domain" }}:443"

    [tracing.openTelemetry.grpc]

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false
    defaultRule = "Host(`{{"{{ .Name }}"}}.{{ key "site/domain" }}`)"

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
[certificatesResolvers]
    [certificatesResolvers.home]
        [certificatesResolvers.home.acme]
	   email = "traefik-dns@philipcristiano.com"
           storage = "alloc/data/acme.json"
           [certificatesResolvers.home.acme.dnsChallenge]
             provider = "dnsimple"
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
