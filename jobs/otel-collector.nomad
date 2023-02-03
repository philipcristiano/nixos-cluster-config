# Nomad adaption of the Docker Compose demo from
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/examples/demo

variables {
  otelcol_img  = "otel/opentelemetry-collector-contrib-dev:latest"
  otelcol_args = []
}

job "otel-collector" {
  datacenters = ["dc1"]
  type        = "service"

  # Collector
  group "otel-collector" {
    network {
      # Prometheus metrics exposed by the collector
      port "metrics" {
        to     = 8888
        static = 8888
      }

      # Receivers
      port "grpc" {
        to = 4317
      }

      # Extensions
      port "pprof" {
        to     = 1888
        static = 1888
      }

      port "zpages" {
        to     = 55679
        static = 55679
      }

      port "health-check" {
        static = 13133
        to     = 13133
      }

      # Exporters
      port "prometheus" {
        to     = 8889
        static = 8889
      }
    }

    service {
      name     = "otel-grpc"
      port     = "grpc"
      tags     = [
        "traefik.enable=true",
	      "traefik.http.routers.otel-grpc.tls=true",
	      "traefik.http.routers.otel-grpc.tls.certresolver=home",
        "traefik.http.services.otel-grpc.loadbalancer.server.scheme=h2c",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "grpc"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name     = "otel-demo-collector"
      port     = "metrics"
      tags     = ["metrics"]
    }

    service {
      name     = "otel-demo-collector"
      port     = "prometheus"
      tags     = ["prometheus"]
    }

    task "otel-collector" {
      driver = "docker"

      config {
        image = var.otelcol_img
        args  = concat(["--config=/etc/otel-collector-config.yaml"], var.otelcol_args)

        ports = [
          "pprof",
          "metrics",
          "prometheus",
          "grpc",
          "health-check",
          "zpages",
        ]

        volumes = [
          "local/otel-collector-config.yaml:/etc/otel-collector-config.yaml",
        ]
      }

      resources {
        cpu    = 200
        memory = 64
      }

      template {
        data = <<EOF
receivers:
  otlp:
    protocols:
      grpc:

exporters:
  logging:

  jaeger:
    endpoint: jaeger-grpc.{{ key "site/domain" }}:443

  zipkin:
    endpoint: "https://zipkin.{{ key "site/domain"}}/api/v2/spans"
    format: proto

processors:
  batch:

extensions:
  health_check:
  pprof:
    endpoint: :{{env "NOMAD_PORT_pprof"}}
  zpages:
    endpoint: :{{env "NOMAD_PORT_zpages"}}

service:
  extensions: [pprof, zpages, health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, jaeger, zipkin]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
EOF

        destination = "local/otel-collector-config.yaml"
      }
    }
  }

}

