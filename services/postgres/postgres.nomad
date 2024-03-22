variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for compute task."
}

variable "backups3_image_id" {
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

      check {
        name     = "JOB_NAME-data-in-place"
        type     = "script"
        task     = "app"
        interval = "10s"
        timeout  = "10s"
        command  = "/bin/bash"
        args     = ["/local/data-in-place.sh"]
      }

    }


    network {

      mode = "bridge"

      port "db" {
  	    to = 5432
      }
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-${ var.name }-postgres"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["db"]

        #entrypoint = ["sleep", "1000"]
        command = "postgres"
        args = ["-c", "config_file=/local/postgres.conf"]
      }

      env {
        POSTGRES_INITDB_ARGS="--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
      }

      template {
        destination = "local/postgres.conf"
        data = file("postgresql.conf.tmpl")
      }

      template {
          env = true
      	  destination = "secrets/pg.env"
          data = <<EOF

{{ with secret "kv/data/JOB_NAME-postgres" }}
POSTGRES_DB = "{{.Data.data.DB}}"
POSTGRES_USER = "{{.Data.data.USER}}"
POSTGRES_PASSWORD = "{{.Data.data.PASSWORD}}"
PGDATA = "{{ env "NOMAD_ALLOC_DIR"}}/data"
{{end}}
          EOF
      }

      template {
        destination = "local/data-in-place.sh"
        data = <<EOF
#!/bin/bash

echo "Check file {{ env "NOMAD_ALLOC_DIR"}}/restored.txt"

if [ -e {{ env "NOMAD_ALLOC_DIR"}}/restored.txt ]
then
    exit 0
else
    exit 2
fi

EOF
      }

      resources {
        cpu    = 128
        memory = 512
        memory_max = 2048
      }
    }

    task "restore_backup" {
      driver = "docker"

      vault {
        policies = ["service-${ var.name }-postgres"]
      }

      lifecycle {
        hook = "poststart"
        sidecar = false
      }

      config {
        image = "${var.docker_registry}${var.backups3_image_id}"

        command = "/bin/sh"
        args = ["/local/restore_backup.sh"]
      }

      template {
        destination = "secrets/file.env"
        env         = true
        data = file("backup_s3.env.tmpl")
      }

      template {
        destination = "local/restore_backup.sh"
        data = <<EOF
set -xe

export POSTGRES_HOST=127.0.0.1
export POSTGRES_PORT=5432

{{ with secret "kv/data/JOB_NAME-postgres" }}

{{ if .Data.data.DB_INIT }}
echo DB_INIT set in secret kv/data/JOB_NAME-postgres, restore failure will still enable the Postgres service
set +e

{{else }}

echo DB_INIT not set in secret kv/data/JOB_NAME-postgres, restore failure will block Postgres service enablement
{{ end }}

{{ end }}
sh ./restore.sh

set -e

touch {{ env "NOMAD_ALLOC_DIR"}}/restored.txt

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
