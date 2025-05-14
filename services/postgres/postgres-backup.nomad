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
    cron             = "*/15 * * * * *"
    prohibit_overlap = true
  }

  group "postgres-backup" {

    restart {
      attempts = 5
      interval = "5m"
      delay    = "10s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 2
      interval       = "5m"
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "60s"
      unlimited      = false
    }

    network {
      dns {
        servers = ["192.168.102.1"]
      }

    }

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

      env {
        PGSSLNEGOTIATION="postgres"
        PGSSLMODE="require"
      }

      resources {
        cpu    = 50
        memory = 200
        memory_max = 300
      }
    }
  }
}
