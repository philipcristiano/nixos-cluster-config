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

job "kanidm" {
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
      name = "kanidm"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.kanidm.tls=true",
	      "traefik.http.routers.kanidm.tls.certresolver=home",
        "traefik.http.services.kanidm.loadbalancer.server.scheme=https",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "12s"
        timeout  = "2s"
      }
    }

    service {
      name = "kanidm-ldap"
      port = "ldap"

      tags = [
        "traefik.enable=true",
	      "traefik.tcp.routers.kanidm-ldap.tls.passthrough=true",
        "traefik.tcp.routers.kanidm-ldap.entrypoints=ldap",
        "traefik.tcp.routers.kanidm-ldap.rule=HostSNI(`*`)",
      ]

      check {
        name     = "kanidm-ldap"
        type     = "tcp"
        port     = "ldap"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "ldap" {
  	    to = 3636
      }
      port "http" {
  	    to = 8443
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "kanidm"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-kanidm"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data"
        read_only   = false
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["ldap", "http"]
        #entrypoint = ["sleep" ,"10000"]
        command = "/sbin/kanidmd"
        args = ["server" ,"-c", "local/kanidm.toml"]

        hostname = "kanidm"
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "local/kanidm.toml"
          data = <<EOF

#   The webserver bind address. Will use HTTPS if tls_*
#   is provided. If set to 443 you may require the
#   NET_BIND_SERVICE capability.
#   Defaults to "127.0.0.1:8443"
bindaddress = "[::]:{{ env "NOMAD_PORT_http" }}"
#
#   The read-only ldap server bind address. The server
#   will use LDAPS if tls_* is provided. If set to 636
#   you may require the NET_BIND_SERVICE capability.
#   Defaults to "" (disabled)
ldapbindaddress = "[::]:{{ env "NOMAD_PORT_ldap" }}"
#
#   HTTPS requests can be reverse proxied by a loadbalancer.
#   To preserve the original IP of the caller, these systems
#   will often add a header such as "Forwarded" or
#   "X-Forwarded-For". If set to true, then this header is
#   respected as the "authoritative" source of the IP of the
#   connected client. If you are not using a load balancer
#   then you should leave this value as default.
#   Defaults to false
trust_x_forward_for = true
#
#   The path to the kanidm database.
db_path = "/data/kanidm.db"
#
#   If you have a known filesystem, kanidm can tune database
#   to match. Valid choices are:
#   [zfs, other]
#   If you are unsure about this leave it as the default
#   (other). After changing this
#   value you must run a vacuum task.
#   - zfs:
#     * sets database pagesize to 64k. You must set
#       recordsize=64k on the zfs filesystem.
#   - other:
#     * sets database pagesize to 4k, matching most
#       filesystems block sizes.
# db_fs_type = "zfs"
#
#   The number of entries to store in the in-memory cache.
#   Minimum value is 256. If unset
#   an automatic heuristic is used to scale this.
# db_arc_size = 2048
#
#   TLS chain and key in pem format. Both must be present
tls_chain = "secrets/chain.pem"
tls_key = "secrets/key.pem"
#
#   The log level of the server. May be default, verbose,
#   perfbasic, perffull
#   Defaults to "default"
# log_level = "default"
#
#   The DNS domain name of the server. This is used in a
#   number of security-critical contexts
#   such as webauthn, so it *must* match your DNS
#   hostname. It is used to create
#   security principal names such as `william@idm.example.com`
#   so that in a (future)
#   trust configuration it is possible to have unique Service
#   Principal Names (spns) throughout the topology.
#   ⚠️  WARNING ⚠️
#   Changing this value WILL break many types of registered
#   credentials for accounts
#   including but not limited to webauthn, oauth tokens, and more.
#   If you change this value you *must* run
#   `kanidmd domain_name_change` immediately after.
domain = "kanidm.{{ key "site/domain" }}"
#
#   The origin for webauthn. This is the url to the server,
#   with the port included if
#   it is non-standard (any port except 443). This must match
#   or be a descendent of the
#   domain name you configure above. If these two items are
#   not consistent, the server WILL refuse to start!
#   origin = "https://idm.example.com"
origin = "https://kanidm.{{ key "site/domain" }}"
#
#   The role of this server. This affects available features
#   and how replication may interact.
#   Valid roles are:
#   - WriteReplica
#     This server provides all functionality of Kanidm. It
#     allows authentication, writes, and
#     the web user interface to be served.
#   - WriteReplicaNoUI
#     This server is the same as a WriteReplica, but does NOT
#     offer the web user interface.
#   - ReadOnlyReplica
#     This server will not writes initiated by clients. It
#     supports authentication and reads,
#     and must have a replication agreement as a source of
#     its data.
#   Defaults to "WriteReplica".
# role = "WriteReplica"
#
[online_backup]
#   The path to the output folder for online backups
path = "/data/backups/"
#   The schedule to run online backups (see https://crontab.guru/)
#   every day at 22:00 UTC (default)
schedule = "@daily"
#   Number of backups to keep (default 7)
versions = 7

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

{{ with secret "pki_int/issue/kanidm" "common_name=kanidm.home.cristiano.cloud" "ttl=24h" "alt_names=localhost,ldap.home.cristiano.cloud" (printf "ip_sans=127.0.0.1,::,%s" (env "attr.unique.network.ip-address"))}}
{{ .Data.private_key }}
{{ end }}

EOF
      }

      template {
          destination = "secrets/chain.pem"
          data = <<EOF
{{ with secret "pki_int/issue/kanidm" "common_name=kanidm.home.cristiano.cloud" "ttl=24h" "alt_names=localhost,ldap.home.cristiano.cloud" (printf "ip_sans=127.0.0.1,::,%s" (env "attr.unique.network.ip-address"))}}
{{ .Data.certificate }}
{{ .Data.ca_chain }}
{{ end }}
EOF
      }

      template {
          destination = "secrets/ca.pem"
          data = <<EOF
{{ with secret "pki_int/issue/kanidm" "common_name=kanidm.home.cristiano.cloud" "ttl=24h" (printf "ip_sans=127.0.0.1,::,%s" (env "attr.unique.network.ip-address"))}}
{{ .Data.issuing_ca }}
{{ end }}
EOF
      }


      resources {
        cpu    = 32
        memory = 64
        memory_max = 512
      }

    }
  }
}
