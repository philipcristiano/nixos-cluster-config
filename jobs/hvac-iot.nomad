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

    task "app" {
      driver = "docker"

      config {
        image = "philipcristiano/hvac-iot-mqtt-influx:0.0.8"
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "debug"
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
          data = <<EOF
          [{hvac_iot, [
            {mqtt_host, "{{key "credentials/hvac-iot/mqtt_host"}}"},
            {mqtt_username, "{{key "credentials/hvac-iot/mqtt_username"}}"},
            {mqtt_password, "{{key "credentials/hvac-iot/mqtt_password"}}"},
            {influxdb_token, "{{key "credentials/hvac-iot/influxdb_token"}}"},
            {influxdb_host, "https://influxdb.{{ key "site/domain" }}"},
            {influxdb_port, 443},
            {influxdb_org, "hazzard"},
            {influxdb_bucket, "environment"}
          ]}].
          EOF

      destination = "local/app.config"
      }

      resources {
        cpu    = 50
        memory = 256
      }

    }
  }
}
