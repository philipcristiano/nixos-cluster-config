
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
  description = "The docker image used for cluster tasks."
  default     = "neondatabase/neon:4205"
}

variable "safekeeper_count" {
  type        = number
  description = "The number of safekeepers to run."
  default     = "3"
}

job "neon" {
  datacenters = ["dc1"]
  type        = "service"

  group "pageserver" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "neon-pageserver"
      port = "pageserver-pg"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.neon-pageserver.entrypoints=neon-pageserver",
        "traefik.tcp.routers.neon-pageserver.rule=HostSNI(`*`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "pageserver-pg"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "neon-pageserver-api"
      port = "pageserver-http"

      tags = [
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.neon-pageserver-api.tls=true",
	      "traefik.http.routers.neon-pageserver-api.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "pageserver-http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "pageserver-http" {
  	    to = 9898
      }
      port "pageserver-pg" {
  	    to = 6400
      }

    }

    task "app" {
      driver = "docker"

      kill_timeout = "600s"

      vault {
        policies = ["service-neon"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["pageserver-http", "pageserver-pg"]
        command = "/usr/local/bin/pageserver"

        args = [
            "-D", "${NOMAD_TASK_DIR}",
            "-c", "id=1",
            "-c", "broker_endpoint=\"${BROKER_ENDPOINT}\"",
            "-c", "listen_pg_addr='0.0.0.0:6400'",
            "-c", "listen_http_addr='0.0.0.0:9898'",
            "-c", "pg_distrib_dir='/usr/local'",
            "-c", "remote_storage={endpoint='https://s3.home.cristiano.cloud:443', bucket_name='neon', bucket_region='eu-north-1', prefix_in_bucket='/pageserver/'}",
        ]

      }

      resources {
        cpu    = 100
        memory = 1024
        memory_max = 4096
      }

      template {
        env = true
        data = <<EOF

BROKER_ENDPOINT=https://neon-storage-broker.{{key "site/domain"}}
{{ with secret "kv/data/neon" }}
AWS_ACCESS_KEY_ID={{.Data.data.AWS_ACCESS_KEY_ID}}
AWS_SECRET_ACCESS_KEY={{.Data.data.AWS_SECRET_ACCESS_KEY}}
{{ end }}

EOF
        destination = "secrets/file.env"
      }

    }
  }

  group "storage-broker" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "neon-storage-broker"
      port = "http"

      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.neon-storage-broker.tls=true",
	    "traefik.http.routers.neon-storage-broker.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	    to = 50051
      }

    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-neon"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        command = "storage_broker"

        args = [
            "--listen-addr", "0.0.0.0:50051"
        ]

      }

      resources {
        cpu    = 10
        memory = 64
        memory_max = 128
      }

      template {
        env = true
        data = <<EOF

BROKER_ENDPOINT=https://neon-storage-broker.{{key "site/domain"}}
{{ with secret "kv/data/neon" }}
{{ end }}

EOF
        destination = "secrets/file.env"
      }

    }
  }

  group "safekeeper" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    count = var.safekeeper_count

    update {
      max_parallel = 1
      min_healthy_time = "60s"
    }

    constraint {
        operator  = "distinct_hosts"
        value     = "true"
    }

    service {
      name = "neon-safekeeper-${NOMAD_ALLOC_INDEX}"
      port = "pg"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.neon-safekeeper-${NOMAD_ALLOC_INDEX}.entrypoints=neon-safekeeper-${NOMAD_ALLOC_INDEX}",
        "traefik.tcp.routers.neon-safekeeper-${NOMAD_ALLOC_INDEX}.rule=HostSNI(`*`)",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/v1/status"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "pg" {
        to = 5454
      }

      port "http" {
  	    to = 9898
      }

    }

    task "app" {
      driver = "docker"
      kill_timeout = "600s"

      vault {
        policies = ["service-neon"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http", "pg"]
        command = "safekeeper"

        args = [
            "-D", "${NOMAD_TASK_DIR}",
            "--id=${SAFEKEEPER_ID}",
            "--broker-endpoint=${BROKER_ENDPOINT}",
            "--listen-pg=0.0.0.0:5454",
            "--listen-http=0.0.0.0:9898",
            "--advertise-pg=neon-safekeeper-${SAFEKEEPER_ID}.home.cristiano.cloud:546${SAFEKEEPER_ID}",
            "--remote-storage={endpoint='https://s3.home.cristiano.cloud:443', bucket_name='neon', bucket_region='eu-north-1', prefix_in_bucket='/safekeeper/'}",
        ]

      }

      resources {
        cpu    = 100
        memory = 512
      }

      template {
        env = true
        data = <<EOF

BROKER_ENDPOINT=https://neon-storage-broker.{{key "site/domain"}}

SAFEKEEPER_ID={{ env "NOMAD_ALLOC_INDEX"  }}
{{ with secret "kv/data/neon" }}

AWS_ACCESS_KEY_ID={{.Data.data.AWS_ACCESS_KEY_ID}}
AWS_SECRET_ACCESS_KEY={{.Data.data.AWS_SECRET_ACCESS_KEY}}

{{ end }}

EOF
        destination = "secrets/file.env"
      }

    }
  }

}
