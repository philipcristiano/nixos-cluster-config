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
}

job "hvac-iot" {
  datacenters = ["dc1"]
  type        = "service"

  group "hvac-iot" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "hvac-iot"

      check {
        name     = "version"
        type     = "script"
        task     = "app"
        command     = "hvac_iot"
        args        = [
            "-h",
        ]
        interval = "10s"
        timeout  = "30s"
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-hvac-iot"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        args = [
            "--config-file", "/secrets/config.toml",
            "--log-json",
            "--log-level", "DEBUG",
        ]
      }
      template {
          destination = "local/otel.env"
          env = true
          data = <<EOF
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
EOF
      }
      template {
          destination = "secrets/config.toml"
          data = <<EOF
[mqtt]
host = "{{key "credentials/hvac-iot/mqtt_host"}}"
port = 1883
id = "hvac_iot"
username = "{{key "credentials/hvac-iot/mqtt_username"}}"
password = "{{key "credentials/hvac-iot/mqtt_password"}}"

[influxdb]
host = "https://influxdb-write.{{ key "site/domain" }}"
bucket = "environment"
token = "{{key "credentials/hvac-iot/influxdb_token"}}"

{{range ls "credentials/hvac-iot/name-mapping"}}
[[sensor]]
id_hex = "{{.Key}}"
[sensor.overwrite]
name = "{{.Value}}"
{{end}}
          EOF

      }

      resources {
        cpu    = 50
        memory = 16
        memory_max = 48
      }

    }
  }
}
