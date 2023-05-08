variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "postgres:14.6"
}

job "postgres-backup" {
  datacenters = ["dc1"]
  type        = "batch"

  # periodic {
  #   cron             = "0 22 * * * *"
  #   prohibit_overlap = true
  # }

  group "postgres-backup" {
    task "postgres-backup" {
      driver = "raw_exec"

      config {
        image = var.id
        command = "psql"
        args    = ["local/script.sh"]
      }

      template {
        data        = <<EOH
        set -e

        nomad alloc exec -task db-task $DB_ALLOC_ID \
        bin/bash -c "PGPASSWORD=$PGPASSWORD PGUSER=$PGUSER PGDATABASE=$PGDATABASE pg_dump --compress=4 -v" | \
        docker run -i --rm \
        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
        d3fk/s3cmd:stable \
        --host=$S3_HOST_BASE \
        --no-ssl \
        --host-bucket=$S3_HOST_BASE -v \
        put - s3://$S3_BUCKET/$(date "+%Y-%m-%d---%H-%M-%S").dump.gz
        EOH
        destination = "local/script.sh"
      }

      template {
        data = <<EOH
{{- with secret "kv-v1/nomad/db/postgres" -}}
PGPASSWORD="{{ .Data.password }}"
PGUSER="{{ .Data.user }}"
PGDATABASE="{{ .Data.db }}"
{{ end }}

{{- with secret "kv-v1/nomad/s3/backup" -}}
AWS_ACCESS_KEY_ID="{{ .Data.access_key_id }}"
AWS_SECRET_ACCESS_KEY="{{ .Data.secret_access_key }}"

# here you also might want to set NOMAD_TOKEN env
# if you're using ACL capabilities
{{ end }}

# as service 'db-task' is registered in Consul
# we wat to grab its 'alloc' tag
{{- range $tag, $services := service "db-task" | byTag -}}
{{if $tag | contains "alloc"}}
{{$allocId := index ($tag | split "=") 1}}
DB_ALLOC_ID="{{ $allocId }}"
{{end}}
{{end}}

# relying on service DNS discovery provided by Consul
# to obtain Minio IP address
S3_HOST_BASE=minio.service.consul:9000
S3_BUCKET=my-bucket-name
        EOH
        destination = "secrets/file.env"
        env         = true

      }
      resources {
        cpu    = 200
        memory = 200
        memory_max = 300
      }
    }
  }
}
