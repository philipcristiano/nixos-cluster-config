variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "grafana/tempo:2.2.1"
}

job "tempo" {
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
      name = "tempo"
      port = "tempo"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.tempo.tls=true",
	    "traefik.http.routers.tempo.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "tempo"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "tempo-otlp-grpc"
      port = "otlp-grpc"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.tempo-otlp-grpc.tls=true",
	    "traefik.http.routers.tempo-otlp-grpc.tls.certresolver=home",
        "traefik.http.services.tempo-otlp-grpc.loadbalancer.server.scheme=h2c",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "otlp-grpc"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "tempo-otlp-http"
      port = "otlp-http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.tempo-otlp-http.tls=true",
	    "traefik.http.routers.tempo-otlp-http.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "otlp-http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "tempo" {
  	   to = 3200
      }
      port "otlp-grpc" {
  	   to = "4317"
      }
      port "otlp-http" {
  	   to = "4318"
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "tempo"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-tempo"]
      }

      config {
        image = var.image_id
        ports = ["tempo", "otlp-grpc", "otlp-http"]
        command = "-config.file=/local/tempo.yaml"
      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      template {
          destination = "local/tempo.yaml"
          data = <<EOF

server:
  http_listen_port: 3200

query_frontend:
  search:
    duration_slo: 5s
    throughput_bytes_slo: 1.073741824e+09
  trace_by_id:
    duration_slo: 5s

distributor:
  receivers:                           # this configuration will listen on all ports and protocols that tempo is capable of.
    jaeger:                            # the receives all come from the OpenTelemetry collector.  more configuration information can
      protocols:                       # be found there: https://github.com/open-telemetry/opentelemetry-collector/tree/main/receiver
        thrift_http:                   #
        grpc:                          # for a production deployment you should only enable the receivers you need!
        thrift_binary:
        thrift_compact:
    zipkin:
    otlp:
      protocols:
        http:
        grpc:
    opencensus:

ingester:
  max_block_duration: 5m               # cut the headblock when this much time passes. this is being set for demo purposes and should probably be left alone normally

compactor:
  compaction:
    block_retention: 1d                # overall Tempo trace retention. set for demo purposes

# metrics_generator:
#   registry:
#     external_labels:
#       source: tempo
#       cluster: docker-compose
#   storage:
#     path: /tmp/tempo/generator/wal
#     remote_write:
#       - url: http://prometheus:9090/api/v1/write
#         send_exemplars: true

storage:
  trace:
    backend: local                     # backend configuration to use
    wal:
      path: /alloc/data/tempo/wal             # where to store the the wal locally
    local:
      path: /storage/tempo/blocks

    # metrics_generator:
    #   processors: [service-graphs, span-metrics] # enables metrics generator


EOF
      }

      resources {
        cpu    = 50
        memory = 256
        memory_max = 1024
      }

    }
  }
}
