variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

variable "name" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"

}

job "JOB_NAME-postgres-backup" {
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

      vault {
        policies = ["service-${ var.name }-postgres"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        command = "pg_dump"
        args = ["-f", "/storage/JOB_NAME-postgres.sql"]
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

{{ with secret "kv/data/JOB_NAME-postgres" }}
PGHOST=JOB_NAME-postgres.{{ key "site/domain" }}
PGPORT=5457
PGUSER={{.Data.data.postgres_username}}
PGPASSWORD={{ .Data.data.postgres_password }}
PGDATABASE={{.Data.data.postgres_username}}

{{ end }}

        EOH

      }
      resources {
        cpu    = 50
        memory = 200
        memory_max = 300
      }
    }
  }
}
