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
    cron             = "0 * * * * *"
    prohibit_overlap = true
  }

  group "postgres-backup" {

    task "postgres-backup" {
      driver = "docker"

      lifecycle {
        hook = "poststart"
        sidecar = false
      }

      vault {
        policies = ["service-${ var.name }-postgres"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
      }

      template {
        destination = "secrets/file.env"
        env         = true
        data = file("backup_s3.env.tmpl")
      }

      resources {
        cpu    = 50
        memory = 200
        memory_max = 300
      }
    }
  }
}
