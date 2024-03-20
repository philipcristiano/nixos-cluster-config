variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for compute task."
}

variable "name" {
  type        = string
  description = ""
}

variable "domain" {
  type        = string
  description = ""
}

job "JOB_NAME-postgres" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "JOB_NAME-postgres"
      port = "db"

      tags = [
        "traefik.enable=true",
	      "traefik.tcp.routers.${var.name}-postgres.tls=true",
	      "traefik.tcp.routers.${var.name}-postgres.tls.certresolver=home",
        "traefik.tcp.routers.${var.name}-postgres.entrypoints=postgres",
        "traefik.tcp.routers.${var.name}-postgres.rule=HostSNI(`${var.name}-postgres.${var.domain}`)",
      ]

      check {
        name     = "JOB_NAME-postgres"
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
      source          = "JOB_NAME-postgres"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-${ var.name }-postgres"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["db"]
        hostname = "JOB_NAME_postgres"
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
      	  destination = "secrets/pg.env"
          data = <<EOF

{{ with secret "kv/data/JOB_NAME-postgres" }}
POSTGRES_DB = "{{.Data.data.DB}}"
POSTGRES_USER = "{{.Data.data.USER}}"
POSTGRES_PASSWORD = "{{.Data.data.PASSWORD}}"
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



