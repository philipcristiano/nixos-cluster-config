variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "kanidm/tools:1.1.0-rc.16"
}

job "kanidm-tools" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-kanidm"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        entrypoint = ["sleep" ,"infinity"]

        hostname = "kanidm-tools"

        mount {
          type     = "bind"
          source   = "local/kanidm.toml"
          target   = "/etc/kanidm/config"
          readonly = false
        }

        mount {
          type     = "tmpfs"
          tmpfs_options {
            size = 100000
          }
          target   = "/home/kanidm/.cache"
          readonly = false
        }
      }

      template {
          destination = "secrets/ca.pem"
          data = <<EOF
{{ with secret "/pki/issuer/default/json"}}
{{ .Data.certificate }}
{{ end }}
EOF
      }

      template {
          destination = "local/kanidm.toml"
          data = <<EOF

tls_chain = "secrets/chain.pem"
tls_key = "secrets/key.pem"

domain = "kanidm.{{ key "site/domain" }}"
uri = "https://kanidm.{{ key "site/domain" }}"

EOF
      }

      resources {
        cpu    = 10
        memory = 128
        memory_max = 1024
      }

    }
  }
}
