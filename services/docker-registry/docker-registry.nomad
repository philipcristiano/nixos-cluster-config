
variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "count" {
  type        = number
  description = "The number of compute containers to run."
  default     = "2"
}

variable "image_id" {
  type        = string
  description = "The docker image used for compute task."
  default     = "registry:2"
}

job "docker-registry" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "60s"
      healthy_deadline = "5m"
    }

    service {
      name = "docker-registry"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.docker-registry.tls=true",
	      "traefik.http.routers.docker-registry.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
        to = 5000
      }

    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-docker-registry"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

        args = [
          "registry",
          "serve",
          "/secrets/config.yml"
        ]

      }

      resources {
        cpu    = 20
        memory = 64
        memory_max = 512
      }

      template {
        destination = "secrets/config.yml"
        data = <<EOF

version: 0.1
http:
  addr: 0.0.0.0:5000
  headers:
    Access-Control-Allow-Origin: ['https://docker-registry-ui.{{ key "site/domain" }}']
{{ with secret "kv/data/docker-registry" }}
http:
  secret: {{ .Data.data.http_secret }}

storage:
  s3:
    accesskey: {{.Data.data.AWS_ACCESS_KEY_ID}}
    secretkey: {{.Data.data.AWS_SECRET_ACCESS_KEY}}
    region: us-west-1
    regionendpoint: https://s3.{{ key "site/domain" }}
    bucket: {{.Data.data.bucket}}
    encrypt: false
    secure: true
    chunksize: 5242880
    multipartcopychunksize: 33554432
    multipartcopymaxconcurrency: 100
    multipartcopythresholdsize: 33554432
    rootdirectory: "/"

{{ end }}

EOF
      }

    }
  }
}
