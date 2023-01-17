job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {

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
        name     = "traefik"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }

      check {
        name     = "alive-https"
        type     = "tcp"
        port     = "https"
        interval = "10s"
        timeout  = "2s"
      }
    }

    #volume "storage" {
    #  type            = "csi"
    #  source          = "traefik"
    #  read_only       = false
    #  attachment_mode = "file-system"
    #  access_mode     = "multi-node-multi-writer"
    #}

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.8"
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
    [entryPoints.http]
    address = ":80"
      [entryPoints.http.http.redirections]
        [entryPoints.http.http.redirections.entryPoint]
          to = "https"
          scheme = "https"
          permanent = true
    [entryPoints.https]
    address = ":443"
    [entryPoints.lorawan-server-udp]
    address = ":1700/udp"
      [entryPoints.lorawan-server-udp.udp]
      timeout= "120s"
    [entryPoints.mqtt]
    address = ":1883"
    [entryPoints.redis-paperless-ngx]
    address = ":6380"
    [entryPoints.traefik]
    address = ":8081"
[serversTransport]
  insecureSkipVerify = true
[api]
    dashboard = true
    insecure  = true
[log]
  level = "INFO"

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false
    defaultRule = "Host(`{{"{{ .Name }}"}}.home.cristiano.cloud`)"

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
