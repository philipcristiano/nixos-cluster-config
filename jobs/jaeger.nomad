# Nomad adaption of the Docker Compose demo from
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/examples/demo

variables {
}

job "jaeger" {
  datacenters = ["dc1"]
  type        = "service"

  # Jaeger
  group "jaeger" {
    network {
      port "ui" {
        to     = 16686
        static = 16686
      }

      port "thrift" {
        to = 14268
      }

      port "grpc" {
        to = 14250
      }
    }

    service {
      name     = "jaeger"
      port     = "ui"
      tags     = [
        "traefik.enable=true",
	    "traefik.http.routers.jaeger.tls=true",
	    "traefik.http.routers.jaeger.tls.certresolver=home",
      ]
      check {
        name     = "jaeger"
        type     = "tcp"
        port     = "ui"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name     = "jaeger-grpc"
      port     = "grpc"
      tags     = [
        "traefik.enable=true",
	    "traefik.http.routers.jaeger-grpc.tls=true",
	    "traefik.http.routers.jaeger-grpc.tls.certresolver=home",
        "traefik.http.services.jaeger-grpc.loadbalancer.server.scheme=h2c",
      ]
      check {
        name     = "jaeger-grpc"
        type     = "tcp"
        port     = "grpc"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "jaeger-all-in-one" {
      driver = "docker"

      config {
        image = "jaegertracing/all-in-one:latest"
        ports = ["ui", "thrift", "grpc"]
      }

      resources {
        cpu    = 200
        memory = 100
      }
    }
  }

}

