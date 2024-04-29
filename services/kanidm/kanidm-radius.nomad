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
}

job "kanidm-radius" {
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
      name = "kanidm-radius"
      port = "radius-auth"

      tags = [
	    "enable_gocast",
        "gocast_vip=192.168.102.51/32",
	      "gocast_monitor=consul",
        "gocast_nat=udp:1812",
        "gocast_nat=tcp:1812",
        "gocast_nat=udp:1813",
      ]

      check {
        name     = "kanidm-radius"
        type     = "script"
        task     = "app"
        command  = "/bin/true"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "radius-auth" {
        static = 1812
  	    to     = 1812
      }
      port "radius-accounting" {
        static = 1813
  	    to     = 1813
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-kanidm"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["radius-auth", "radius-accounting"]
        #entrypoint = ["sleep" ,"10000"]
        args = ["/usr/bin/python3", "/radius_entrypoint.py"]

        mount {
          type     = "bind"
          source   = "local/kanidm.toml"
          target   = "/data/kanidm"
          readonly = true
        }
      }

      env {
 	      CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
        DEBUG="True"
        KANIDM_CONFIG_FILE="/local/kanidm.toml"
      }
      template {
          destination = "local/kanidm.toml"
          data = <<EOF
uri = "https://kanidm.{{ key "site/domain"}}" # URL to the Kanidm server
verify_hostnames = true     # verify the hostname of the Kanidm server

verify_ca = "false"           # Strict CA verification
ca = "/secrets/ca.pem"           # Path to the kanidm ca

{{with secret "kv/data/kanidm"}}

auth_token = "{{ .Data.data.radius_sa_auth_token }}" # Auth token for the service account
                            # See: kanidm service-account api-token generate

{{ end }}
# Default vlans for groups that don't specify one.
radius_default_vlan = 1

# A list of Kanidm groups which must be a member
# before they can authenticate via RADIUS.
radius_required_groups = [
{{ with secret "kv/data/radius/required_groups" }}
  {{ range $k, $v := .Data.data }}
  "{{ $k }}",
{{ end }}
]
{{ end }}

# A mapping between Kanidm groups and VLANS
radius_groups = [
{{ with secret "kv/data/radius/groups" }}
  {{ range $k, $v := .Data.data }}
  {{ $v }},
{{ end }}
]
{{ end }}
# A mapping of clients and their authentication tokens
radius_clients = [
{{ with secret "kv/data/radius/clients" }}
  {{ range $k, $v := .Data.data }}
  {{ $v }},
{{ end }}
]
{{ end }}

radius_cert_path = "/secrets/cert.pem"
# the signing key for radius TLS
radius_key_path = "/secrets/key.pem"
# the diffie-hellman output
radius_dh_path = "/alloc/data/dh.pem"
# the CA certificate
radius_ca_path = "/secrets/ca.pem"

EOF
      }
      template {
          destination = "local/app.env"
          env = true
          data = <<EOF

OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc

EOF
      }
      template {
          destination = "secrets/key.pem"
          data = <<EOF

{{ with secret "pki_int/issue/kanidm" "common_name=radius.home.cristiano.cloud" "ttl=30d" "alt_names=localhost" (printf "ip_sans=127.0.0.1,::,%s" (env "attr.unique.network.ip-address"))}}
{{ .Data.private_key }}
{{ end }}

EOF
      }

      template {
          destination = "secrets/cert.pem"
          data = <<EOF
{{ with secret "pki_int/issue/kanidm" "common_name=radius.home.cristiano.cloud" "ttl=30d" "alt_names=localhost" (printf "ip_sans=127.0.0.1,::,%s" (env "attr.unique.network.ip-address"))}}
{{ .Data.certificate }}
{{ end }}
EOF
      }

      template {
          destination = "secrets/ca.pem"
          data = <<EOF
{{ with secret "pki_int/issue/kanidm" "common_name=radius.home.cristiano.cloud" "ttl=30h" (printf "ip_sans=127.0.0.1,::,%s" (env "attr.unique.network.ip-address"))}}
{{ .Data.issuing_ca }}
{{ end }}
EOF
      }


      resources {
        cpu    = 32
        memory = 128
        memory_max = 512
      }

    }

    task "ca_openssl_prep" {
      driver = "docker"

      vault {
        policies = ["service-kanidm"]
      }

      lifecycle {
        hook = "prestart"
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        command = "openssl"
        args = [
          "dhparam",
          "-in",
          "/secrets/ca.pem",
          "-out",
          "/alloc/data/dh.pem",
          "2048",
        ]

      }

      resources {
        cpu    = 32
        memory = 32
        memory_max = 512
      }

      template {
          destination = "secrets/ca.pem"
          data = <<EOF
{{ with secret "pki_int/issue/kanidm" "common_name=radius.home.cristiano.cloud" "ttl=24h" (printf "ip_sans=127.0.0.1,::,%s" (env "attr.unique.network.ip-address"))}}
{{ .Data.issuing_ca }}
{{ end }}
EOF
      }
    }
  }
}
