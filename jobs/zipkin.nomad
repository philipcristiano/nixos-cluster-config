# Nomad adaption of the Docker Compose demo from
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/examples/demo

variables {
}

job "zipkin" {
  datacenters = ["dc1"]
  type        = "service"

  # Zipkin
  group "zipkin-all-in-one" {
    network {
      port "http" {
        to     = 9411
      }
    }

    service {
      name     = "zipkin"
      port     = "http"
      tags     = [
        "traefik.enable=true",
	    "traefik.http.routers.zipkin.tls=true",
	    "traefik.http.routers.zipkin.tls.certresolver=home",
        "traefik.http.services.zipkin.loadbalancer.server.scheme=h2c",
      ]

      check {
        name     = "zipkin"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "zipkin-all-in-one" {
      driver = "docker"

      config {
        image = "openzipkin/zipkin:2.24.0"
        ports = ["http"]
      }

      resources {
        cpu    = 250
        memory = 350
      }
    }
  }

}

