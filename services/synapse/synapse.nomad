variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "philipcristiano/synapse-omni:1.100.0"
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
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.synapse.tls=true",
        "traefik.http.routers.synapse.entrypoints=http,https,http-public,https-public",
        "traefik.http.routers.synapse.rule=( Host(`matrix.philipcristiano.com`)  && !PathPrefix(`/_synapse/admin`) && !PathPrefix(`/_synapse/metrics`) ) || Host(`matrix.home.cristiano.cloud`)",
	    "traefik.http.routers.synapse.tls.certresolver=home",
      ]

      meta {
        metrics_path = "/_synapse/metrics"
      }

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
  	    to = 8086
      }
    }

    task "app" {
      driver = "docker"
      user = 991

      vault {
        policies = ["service-synapse"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 512
        memory_max = 2048
      }

      env = {
        SYNAPSE_CONFIG_PATH = "secrets/synapse.config"
      }

      template {
          destination = "secrets/synapse.config"
          data = <<EOF
# For more information on how to configure Synapse, including a complete accounting of
# each option, go to docs/usage/configuration/config_documentation.md or
# https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html

server_name: "{{ key "site/public_domain" }}"

public_baseurl: https://matrix.{{ key "site/public_domain"}}/
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
{{with secret "kv/data/synapse-postgres"}}
database:
  name: psycopg2
  args:
    user: {{.Data.data.postgres_username}}
    password: {{ .Data.data.postgres_password }}
    database: {{.Data.data.postgres_username}}
    host: synapse-postgres.{{ key "site/domain" }}
    port: 5457

    cp_min: 5
    cp_max: 10
{{ end }}

{{with secret "kv/data/synapse"}}

signing_key: "{{.Data.data.SIGNING_KEY }}"

oidc_providers:
  - idp_id: kanidm
    idp_name: "SSO"
    issuer: "https://kanidm.{{ key "site/domain"}}/oauth2/openid/{{.Data.data.OAUTH_CLIENT_ID }}"
    pkce_method: always
    allow_existing_users: true
    client_id: "{{.Data.data.OAUTH_CLIENT_ID }}"
    client_secret: "{{.Data.data.OAUTH_CLIENT_SECRET }}"
    scopes: ["openid", "profile"]
    user_mapping_provider:
      config:
        localpart_template: "{{"{{"}} user.name {{"}}"}}"
        display_name_template: "{{"{{"}} user.name {{"}}"}}"
    # backchannel_logout_enabled: true # Optional
{{ end }}

enable_metrics: true

log_config: "/local/log.config"
media_store_path: "/tmp"
trusted_key_servers:
  - server_name: "matrix.org"

# registration_shared_secret: "shared-secret"

report_stats: true


# Application services
app_service_config_files:
- /local/heisenbridge.yaml

media_storage_providers:
# S3 Storage provider
{{with secret "kv/data/synapse"}}
- module: s3_storage_provider.S3StorageProviderBackend
  store_local: True
  store_remote: True
  store_synchronous: True
  config:
    bucket: "{{ .Data.data.BUCKET_NAME }}"
    # All of the below options are optional, for use with non-AWS S3-like
    # services, or to specify access tokens here instead of some external method.
    endpoint_url: "https://s3.{{ key "site/domain"}}:443"
    access_key_id: "{{ .Data.data.ACCESS_KEY_ID }}"
    secret_access_key: "{{ .Data.data.SECRET_ACCESS_KEY }}"
{{ end }}


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



