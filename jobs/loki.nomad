job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "loki"
      port = "http"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.loki.tls=true",
	"traefik.http.routers.loki.tls.certresolver=home",
      ]

      check {
        name     = "loki"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
	to = 3100
      }
      port "grpc" { 
	to = 9096
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "loki"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "grafana/loki:2.4.2"
        ports = ["http"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/storage/"
      }
      template {
	destination = "/etc/local-config.yaml"
        data =  <<EOF
auth_enabled: false

server:
  http_listen_port: ${ NOMAD_PORT_http }
  grpc_listen_port: ${ NOMAD_PORT_grpc }

common:
  path_prefix: /storage/loki
  storage:
    filesystem:
      chunks_directory: /storage/loki/chunks
      rules_directory: /storage/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093
      EOF
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

    }
  }
}



