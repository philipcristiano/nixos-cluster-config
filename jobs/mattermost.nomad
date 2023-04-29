job "mattermost" {
  datacenters = ["dc1"]
  type        = "service"

  group "mattermost" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }
    service {
      name = "mattermost"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.mattermost.tls=true",
	      "traefik.http.routers.mattermost.tls.certresolver=home",
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
  	    to = 8065
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "mattermost"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "mattermost/mattermost-team-edition:release-7.10"
        ports = ["http"]
      }
      env {
 	    CONFIG_ROOT = "/local"
        LOG_LEVEL = "info"
      }
      template {
          destination = "local/mattermost.json"
          env = true
          data = <<EOF
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-grpc.{{ key "site/domain" }}:443
OTEL_EXPORTER_OTLP_PROTOCOL=grpc

MM_SQLSETTINGS_DRIVERNAME=postgres
MM_SQLSETTINGS_DATASOURCE=postgres://{{ key "credentials/mattermost-postgres/USER" }}:{{ key "credentials/mattermost-postgres/PASSWORD" }}@mattermost-postgres.{{key "site/domain"}}:5435/{{ key "credentials/mattermost-postgres/DB" }}?sslmode=disable&connect_timeout=10

MM_FILESETTINGS_DRIVERNAME=local
MM_FILESETTINGS_DIRECTORY=/storage/storage

EOF
      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      resources {
        cpu    = 125
        memory = 1024
        memory_max = 2048
      }

    }
  }
}
