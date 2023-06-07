variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "postgres:15.3"
}

job "nostr-rs-relay-postgres-backup" {
  datacenters = ["dc1"]
  type        = "batch"

  periodic {
    cron             = "0 22 * * * *"
    prohibit_overlap = true
  }

  group "postgres-backup" {

    volume "storage" {
      type            = "csi"
      source          = "postgres-backup"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }


    task "postgres-backup" {
      driver = "docker"

      config {
        image = var.image_id
        command = "pg_dump"
        args = ["-f", "/storage/nostr-rs-relay.sql"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
        read_only   = false
      }

      template {
        destination = "secrets/file.env"
        env         = true
        data        = <<EOH

PGPASSWORD="{{ key "credentials/nostr-rs-relay-postgres/PASSWORD" }}"
PGHOST="nostr-rs-relay-postgres.{{ key "site/domain" }}"
PGPORT={{ key "traefik-ports/nostr-rs-relay-postgres" }}
PGUSER="{{ key "credentials/nostr-rs-relay-postgres/USER" }}"
PGDATABASE="{{ key "credentials/nostr-rs-relay-postgres/DB" }}"

        EOH

      }
      resources {
        cpu    = 200
        memory = 200
        memory_max = 300
      }
    }
  }
}
