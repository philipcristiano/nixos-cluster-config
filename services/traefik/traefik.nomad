variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Domain of this instance"
}

// Update services/docker-prefetch-image when this changes
variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "traefik:v3.0.0-rc1"
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

  update {
    max_parallel = 1
    stagger      = "300s"
  }

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

      port "postgres" {
        static = 5457
      }

      port "redis" {
        static = 6379
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
        interval = "3s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        #image = "${var.image_id}"
        image = "${var.docker_registry}${var.image_id}"
        network_mode = "host"
        ports = [
          "api",
          "http",
          "https",
          "lorawan-server-udp",
          "postgres",
          "redis",
        ]

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

    ## POTENTIALLY PUBLIC ENTRYPOINTS
    [entryPoints.lightning-p2p]
    address = ":9735"

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
    [entryPoints.syslog-udp]
    address = ":1514/udp"
      [entryPoints.syslog-udp.udp]
      timeout= "120s"
    [entryPoints.lorawan-server-udp]
    address = ":1700/udp"
      [entryPoints.lorawan-server-udp.udp]
      timeout= "120s"

    [entryPoints.postgres]
    address = ":{{ env "NOMAD_PORT_postgres" }}"
    [entryPoints.redis]
    address = ":{{ env "NOMAD_PORT_redis" }}"
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
  [tracing.otlp]

    [tracing.otlp.grpc]
      endpoint = "tempo-otlp-grpc.{{ key "site/domain" }}:443"


[metrics]
  [metrics.influxDB2]
    address= "https://influxdb-write.{{ key "site/domain" }}:443"
    org = "{{ key "credentials/traefik/influxdb_organization"}}"
    bucket = "{{ key "credentials/traefik/influxdb_bucket"}}"
    token = "{{ key "credentials/traefik/influxdb_token"}}"
    addEntryPointsLabels = true
    addRoutersLabels = true
    addServicesLabels = true
    [metrics.influxDB2.additionalLabels]
      traefik_host = "{{ env "NOMAD_ALLOC_ID" }}"

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
        memory_max = 512
      }
    }
  }
}
