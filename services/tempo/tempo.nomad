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

    ephemeral_disk {
      # Used to store index, cache, WAL
      # Nomad will try to preserve the disk between job updates
      size   = 1000
      sticky = true
    }

    # volume "storage" {
    #   type            = "csi"
    #   source          = "tempo"
    #   read_only       = false
    #   attachment_mode = "file-system"
    #   access_mode     = "multi-node-multi-writer"
    # }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-tempo"]
      }

      config {
        image = var.image_id
        ports = ["tempo", "otlp-grpc", "otlp-http"]
        command = "-config.file=/secrets/tempo.yaml"
      }

      # volume_mount {
      #   volume      = "storage"
      #   destination = "/storage"
      # }

      template {
          destination = "secrets/tempo.yaml"
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


{{ with secret "kv/data/tempo" }}
storage:
  trace:
    backend: s3                        # backend configuration to use
    wal:
      path: /alloc/data/tempo/wal             # where to store the the wal locally
    s3:
      bucket: {{.Data.data.bucket}}                    # how to store data in s3
      endpoint: "s3.{{key "site/domain"}}:443"
      access_key: "{{.Data.data.ACCESS_KEY}}"
      secret_key: "{{.Data.data.SECRET_KEY}}"
{{ end }}


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
