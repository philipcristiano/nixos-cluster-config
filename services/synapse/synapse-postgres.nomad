variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "postgres:15.3"
}

job "synapse-postgres" {
  datacenters = ["dc1"]
  type        = "service"

  group "db" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "synapse-postgres"
      port = "db"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.synapse-postgres.entrypoints=synapse-postgres",
        "traefik.tcp.routers.synapse-postgres.rule=HostSNI(`*`)",
      ]

      check {
        name     = "synapse-postgres"
        type     = "tcp"
        port     = "db"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "db" {
  	    to = 5432
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "synapse-postgres"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"
      kill_timeout = "600s"

      config {
        image = var.image_id
        ports = ["db"]
        hostname = "synapse_postgres"
      }

      volume_mount {
        volume      = "storage"
        destination = "/var/lib/postgresql/data/"
      }

      env {
        POSTGRES_INITDB_ARGS="--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
      }

      template {
          env = true
      	  destination = "secrets/pg"
          data = <<EOF
{{range ls "credentials/synapse-postgres"}}
POSTGRES_{{.Key}}={{.Value}}
{{end}}
          EOF
      }

      resources {
        cpu    = 128
        memory = 512
        memory_max = 2048
      }

    }
  }
}



