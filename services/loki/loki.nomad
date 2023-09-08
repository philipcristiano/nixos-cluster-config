variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "grafana/loki:2.9.0"
}

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

    # volume "storage" {
    #   type            = "csi"
    #   source          = "loki"
    #   read_only       = false
    #   attachment_mode = "file-system"
    #   access_mode     = "multi-node-multi-writer"
    # }

    # task "prep-disk" {

    #   driver = "docker"
    #   # volume_mount {
    #   #   volume      = "storage"
    #   #   destination = "/storage"
    #   #   read_only   = false
    #   # }
    #   config {
    #     image        = "busybox:latest"
    #     command      = "sh"
    #     args         = ["-c", "mkdir -p /storage/data && chown -R 10001:10001 /storage && chmod 775 /storage"]
    #   }
    #   resources {
    #     cpu    = 200
    #     memory = 128
    #   }

    #   lifecycle {
    #     hook    = "prestart"
    #     sidecar = false
    #   }
    # }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-loki"]
      }

      config {
        image = var.image_id
        ports = ["http"]

        args = [
          "-config.file", "secrets/config.yaml"
        ]

      }

      # volume_mount {
      #   volume      = "storage"
      #   destination = "/storage/"
      # }

      template {
	      destination = "secrets/aws.env"
        env = true
        data =  <<EOF

{{ with secret "kv/data/loki" }}
AWS_ACCESS_KEY_ID={{.Data.data.ACCESS_KEY}}
AWS_SECRET_ACCESS_KEY={{.Data.data.SECRET_KEY}}
{{ end }}
EOF
      }

      template {
	      destination = "secrets/config.yaml"
        data =  <<EOF
auth_enabled: false

server:
  http_listen_port: {{ env "NOMAD_PORT_http" }}
  grpc_listen_port: {{ env "NOMAD_PORT_grpc" }}
#
# Filesystem storage
#
#storage_config:
#  filesystem:
#    directory: /storage/loki
#  boltdb_shipper:
#    active_index_directory: /storage/index
#    shared_store: filesystem
#    cache_location: /storage/boltdb-cache

#
# Minio Storage
#

{{ with secret "kv/data/loki" }}
storage_config:
  boltdb_shipper:
    active_index_directory: /alloc/data/loki/index
    cache_location: /alloc/data/loki/index_cache
    resync_interval: 5s
    shared_store: aws
  aws:
    access_key_id: "{{.Data.data.ACCESS_KEY}}"
    secret_access_key: "{{.Data.data.SECRET_KEY}}"
    s3: "https://s3.{{key "site/domain"}}.:443/{{.Data.data.bucket}}"
    s3forcepathstyle: true

{{ end }}

  tsdb_shipper:
    active_index_directory: /alloc//data/tsdb-index
    cache_location: /alloc//data/tsdb-cache
    # index_gateway_client:
    #   # only applicable if using microservices where index-gateways are independently deployed.
    #   # This example is using kubernetes-style naming.
    #   server_address: dns:///index-gateway.<namespace>.svc.cluster.local:9095
    shared_store: s3

common:
  path_prefix: /alloc/data/loki
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: aws
      schema: v12
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 7d

ruler:
  alertmanager_url: http://localhost:9093
EOF
      }

      resources {
        cpu    = 100
        memory = 256
        memory_max = 1024
      }

    }
  }
}



