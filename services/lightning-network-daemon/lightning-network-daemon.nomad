variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = ""
}
variable "lnd_image_id" {
  type        = string
  description = "The docker image used for lnd."
  default     = "lightninglabs/lnd:v0.17.3-beta"
}

variable "terminal_image_id" {
  type        = string
  description = "The docker image used for lightning terminal."
  default     = "lightninglabs/lightning-terminal:v0.12.1-alpha"
}

variable "tor_image_id" {
  type        = string
  description = "The docker image used for tor task."
  default     = "osminogin/tor-simple:0.4.7.13"
}

variable "lndmon_image_id" {
  type        = string
  description = "The docker image used for tor task."
  default     = "lightninglabs/lndmon:v0.2.7"
}

job "lightning-network-daemon" {
  datacenters = ["dc1"]
  type        = "service"

  group "lnd" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "lnd-rest"
      port = "lnd-rest"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.lnd-rest.tls=true",
	      "traefik.http.routers.lnd-rest.tls.certresolver=home",
      ]

      check {
        name     = "lnd-rest"
        type     = "tcp"
        port     = "lnd-rest"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "lnd-p2p"
      port = "lnd-p2p"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.lnd-p2p.entrypoints=lightning-p2p",
        "traefik.tcp.routers.lnd-p2p.rule=HostSNI(`*`)",
      ]

      check {
        name     = "lnd-p2p"
        type     = "tcp"
        port     = "lnd-p2p"
        interval = "30s"
        timeout  = "2s"
      }
    }

    service {
      name = "lnd-prometheus"
      port = "lnd-prometheus"

      tags = [
        "prometheus",
      ]

      check {
        name     = "lnd-p2p"
        type     = "tcp"
        port     = "lnd-p2p"
        interval = "30s"
        timeout  = "2s"
      }
    }

    service {
      name = "lightning-terminal"
      port = "terminal-http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.terminal-http.tls=true",
	      "traefik.http.routers.terminal-http.tls.certresolver=home",
        "traefik.http.services.terminal-http.loadbalancer.server.scheme=https",
      ]

      check {
        name     = "terminal-http"
        type     = "tcp"
        port     = "terminal-http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "lndmon"
      port = "lndmon"

      tags = [
        "prometheus",
      ]

      check {
        name     = "lndmon"
        type     = "http"
        port     = "lndmon"
        path     = "/metrics"
        interval = "30s"
        timeout  = "2s"
      }
    }


    network {

      mode = "bridge"

      port "lnd-p2p" {
        to = 9735
      }

      port "lnd-rest" {
        to = 8080
      }

      port "lnd-prometheus" {
        to = 8989
      }

      port "lnd-rpc" {
        to = 10009
      }

      port "terminal-http" {
        to = 8443
      }
      port "lndmon" {
        to = 9092
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "lightning-network-daemon-storage"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    ephemeral_disk {
      migrate = false
      size    = 500
      sticky  = false
    }

    task "lnd" {
      driver = "docker"

      kill_timeout = "600s"

      vault {
        policies = ["service-lightning-network-daemon"]
      }

      config {
        #image = var.lnd_image_id
        image = "${var.docker_registry}${var.lnd_image_id}"
        ports = ["lnd-rest", "lnd-p2p", "lnd-prometheus"]

        # entrypoint = ["sleep", "10000"]
        args = [
          "--configfile=/secrets/lnd.conf"
        ]

      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      env {}

      template {
          destination = "secrets/wallet-unlock-password-file"
          data = <<EOF
{{with secret "kv/data/lightning-network-daemon"}}{{ if eq (index .Data.data "wallet_unlock_password") "" }}No password found {{.Data.data}} {{ .Data.data.wallet_unlock_password}}{{else }}{{- .Data.data.wallet_unlock_password -}}{{ end }}{{ end }}
EOF
      }

      template {
      	  destination = "secrets/lnd.conf"
          data = file("lnd.conf.tmpl")
      }

      resources {
        cpu    = 100
        memory = 512
        memory_max = 4096
      }

    }

    task "terminal" {
      driver = "docker"

      vault {
        policies = ["service-lightning-terminal"]
      }
      lifecycle {
        hook = "poststart"
        sidecar = true
      }

      config {
        #image = var.terminal_image_id
        image = "${var.docker_registry}${var.terminal_image_id}"
        ports = ["terminal-http"]

        # entrypoint = ["sleep", "10000"]
        args = [
          "--configfile=/secrets/lit.conf"
        ]

      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      template {
          destination = "secrets/lit.conf"
          data = file("lit.conf.tmpl")
      }

      resources {
        cpu    = 24
        memory = 64
        memory_max = 256
      }

    }

    task "lndmon" {
      driver = "docker"

      lifecycle {
        hook = "poststart"
        sidecar = true
      }

      config {
        image = "${var.docker_registry}${var.lndmon_image_id}"
        ports = ["lndmon"]

        args = [
          "--prometheus.listenaddr=0.0.0.0:9092",
          "--lnd.macaroondir=${MACAROON_PATH}",
          "--lnd.tlspath=${TLS_CERT_PATH}",
        ]
      }

      template {
          destination = "local/lndmon.env"
          env = true
          data = <<EOF

TLS_CERT_PATH=/alloc/data/tls/tls.cert
MACAROON_PATH=/alloc/data/chain/bitcoin/mainnet/

EOF
      }

      resources {
        cpu    = 24
        memory = 128
        memory_max = 512
      }

    }

    task "tor" {
      driver = "docker"

      vault {
        policies = ["service-tor"]
      }

      config {
        #image = var.tor_image_id
        image = "${var.docker_registry}${var.tor_image_id}"
        # entrypoint = ["sleep", "10000"]

        mount {
          type     = "bind"
          source   = "secrets/torrc"
          target   = "/etc/tor/torrc"
          readonly = true
        }

      }

      resources {
        cpu    = 50
        memory = 64
        memory_max = 256
      }

      template {
        destination = "secrets/torrc"
        data = file("torrc.tmpl")
      }

    }
  }
}
