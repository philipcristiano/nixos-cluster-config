
variable "image_id" {
  type        = string
  description = "The docker image used for compute task."
  default     = "neondatabase/compute-node-v16:3771"
}

variable "count" {
  type        = number
  description = "The number of compute containers to run."
  default     = "1"
}

job "forgejo-compute" {
  datacenters = ["dc1"]
  type        = "service"

  group "compute" {

    count = var.count

    constraint {
        operator  = "distinct_hosts"
        value     = "true"
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "forgejo-postgres"
      port = "pg"

      tags = [
        "traefik.enable=true",
	      "traefik.tcp.routers.forgejo-postgres.tls=true",
	      "traefik.tcp.routers.forgejo-postgres.tls.certresolver=home",
        "traefik.tcp.routers.forgejo-postgres.entrypoints=neon-postgres",
        "traefik.tcp.routers.forgejo-postgres.rule=HostSNI(`forgejo-postgres.home.cristiano.cloud`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "pg"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {

      port "http" {
        to = 3080
      }
      port "pg" {
        to = 55433
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-forgejo"]
      }

      config {
        image = var.image_id
        ports = ["http", "pg"]
        # command = "/usr/local/bin/compute_ctl"

        args = [
            "--pgdata", "/alloc/data",
            "-C", "postgresql://cloud_admin@localhost:55433/postgres",
            "-b", "/usr/local/bin/postgres",
            "-S", "/secrets/spec.json",
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

EOF
        destination = "secrets/file.env"
      }

      template {
        data = file("neon_spec.json")
        destination = "secrets/spec.json"
      }

    }
  }
}
