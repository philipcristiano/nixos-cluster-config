variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = "codeberg.org/"
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "forgejo/forgejo:1.20.5-0"
}

job "forgejo" {
  datacenters = ["dc1"]
  type        = "service"

  group "forgejo" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }
    service {
      name = "forgejo-ssh"
      port = "ssh"

      tags = [
	    "enable_gocast",
        "gocast_vip=192.168.102.52/32",
	    "gocast_monitor=consul",
        "gocast_nat=tcp:22:${NOMAD_HOST_PORT_ssh}",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "ssh"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "forgejo"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.forgejo.tls=true",
	    "traefik.http.routers.forgejo.tls.certresolver=home",

        # Enable SSH/GoCast BGP if the HTTP server is running
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
      port "http" {
  	    to = 3000
      }
      port "ssh" {
        static = 5501
  	    to = 22
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "forgejo"
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
        args         = ["-c", "mkdir -p /storage && chown -R 9999:0 /storage && chmod 775 /storage"]
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

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-forgejo"]
      }

      config {
        # entrypoint = ["sleep", "10000"]
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http", "ssh"]
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "secrets/config.env"
          env = true
          data = <<EOF
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-http.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=http/json

{{ with secret "kv/data/forgejo-postgres" }}
FORGEJO__database__DB_TYPE=postgres
FORGEJO__database__HOST=forgejo-postgres.{{ key "site/domain" }}:5457
FORGEJO__database__SSL_MODE=require
FORGEJO__database__NAME={{.Data.data.postgres_username}}
FORGEJO__database__USER={{.Data.data.postgres_username}}
FORGEJO__database__PASSWD={{ .Data.data.postgres_password }}
{{ end }}

FORGEJO__server__SSH_DOMAIN=git.{{ key "site/domain"}}

EOF
      }

      volume_mount {
        volume      = "storage"
        destination = "/data"
      }

      resources {
        cpu    = 125
        memory = 1024
        memory_max = 2048
      }

    }
  }
}
