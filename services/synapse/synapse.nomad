variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "matrixdotorg/synapse:v1.86.0"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "synapse" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"

      auto_promote     = true
      canary           = 1
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "synapse"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.synapse.tls=true",
        "traefik.http.routers.synapse.entrypoints=http,https,http-public,https-public",
        "traefik.http.routers.synapse.rule=( Host(`matrix.philipcristiano.com`)  && !PathPrefix(`/_synapse/admin`) && !PathPrefix(`/_synapse/metrics`) ) || Host(`matrix.home.cristiano.cloud`)",
	    "traefik.http.routers.synapse.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "_matrix/static/"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
  	    to = 8086
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "synapse"
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
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R 1000:1000 /storage && chmod 775 /storage"]
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
      user = 1000

      vault {
        policies = ["service-synapse"]
      }

      config {
        image = var.image_id
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data"
      }

      resources {
        cpu    = 100
        memory = 512
        memory_max = 2048
      }

      env = {
        SYNAPSE_CONFIG_PATH = "local/synapse.config"
      }

      template {
          destination = "local/synapse.config"
          data = <<EOF
# For more information on how to configure Synapse, including a complete accounting of
# each option, go to docs/usage/configuration/config_documentation.md or
# https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html
server_name: "{{ key "site/public_domain" }}"
pid_file: /homeserver.pid
listeners:
  - port: {{ env "NOMAD_PORT_http" }}
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation, metrics]
        compress: false

# Postgres DB
database:
  name: psycopg2
  args:
    user: {{ key "credentials/synapse-postgres/USER" }}
    password: {{ key "credentials/synapse-postgres/PASSWORD" }}
    database: {{ key "credentials/synapse-postgres/DB" }}
    host: synapse-postgres.{{ key "site/domain" }}
    port: {{ key "traefik-ports/synapse-postgres" }}

    cp_min: 5
    cp_max: 10

enable_metrics: true

log_config: "local/log.config"
media_store_path: /data/media_store
signing_key_path: "/data/{{ key "site/public_domain" }}.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"

# registration_shared_secret: "shared-secret"

report_stats: true


# Application services
app_service_config_files:
- /local/heisenbridge.yaml

EOF
      }


      template {
          destination = "local/log.config"
          data = <<EOF
# Log configuration for Synapse.
#
# This is a YAML file containing a standard Python logging configuration
# dictionary. See [1] for details on the valid settings.
#
# Synapse also supports structured logging for machine readable logs which can
# be ingested by ELK stacks. See [2] for details.
#
# [1]: https://docs.python.org/3/library/logging.config.html#configuration-dictionary-schema
# [2]: https://matrix-org.github.io/synapse/latest/structured_logging.html

version: 1

formatters:
    precise:
        format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
    console:
        class: logging.StreamHandler
        formatter: precise

loggers:
    synapse.storage.SQL:
        # beware: increasing this to DEBUG will make synapse log sensitive
        # information such as access tokens.
        level: INFO

root:
    level: INFO

    # Write logs to the `buffer` handler, which will buffer them together in memory,
    # then write them to a file.
    #
    # Replace "buffer" with "console" to log to stderr instead. (Note that you'll
    # also need to update the configuration for the `twisted` logger above, in
    # this case.)
    #
    handlers: [console]

disable_existing_loggers: false
EOF
        }

      template {
          destination = "local/heisenbridge.yaml"
          data = <<EOF

id: heisenbridge
url: https://heisenbridge.{{ key "site/domain" }}

{{with secret "kv/data/heisenbridge"}}
as_token: "{{.Data.data.as_token}}"
hs_token: "{{.Data.data.hs_token}}"
{{end}}

rate_limited: false
sender_localpart: heisenbridge
namespaces:
    users:
    - regex: '@irc_.*'
      exclusive: true
    aliases: []
    rooms: []

EOF
      }
    }
  }
}



