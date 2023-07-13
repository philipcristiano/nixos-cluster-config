variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "traefik:v3.0.0-beta3"
}

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

      port "api" {
        static = 8081
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
        image        = var.image_id
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

    [entryPoints.http-public]
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
    [entryPoints.traefik]
    address = ":8081"

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


[metrics]
  [metrics.influxDB2]
    address= "https://influxdb.{{ key "site/domain" }}:443"
    org = "{{ key "credentials/traefik/influxdb_organization"}}"
    bucket = "{{ key "credentials/traefik/influxdb_bucket"}}"
    token = "{{ key "credentials/traefik/influxdb_token"}}"
    addEntryPointsLabels = true
    addRoutersLabels = true
    addServicesLabels = true

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

[tls.stores]
  [tls.stores.default.defaultGeneratedCert]
    resolver = "home"
    [tls.stores.default.defaultGeneratedCert.domain]
      main = "home.cristiano.cloud"
      sans = ["*.home.cristiano.cloud"]

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
