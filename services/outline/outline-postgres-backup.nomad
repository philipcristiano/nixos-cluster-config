variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "postgres:14.6"
}

job "outline-postgres-backup" {
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
        args = ["-f", "/storage/outline.sql"]
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

PGPASSWORD="{{ key "credentials/outline-postgres/PASSWORD" }}"
PGHOST="outline-postgres.{{ key "site/domain" }}"
PGPORT=5436
PGUSER="{{ key "credentials/outline-postgres/USER" }}"
PGDATABASE="{{ key "credentials/outline-postgres/DB" }}"

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
