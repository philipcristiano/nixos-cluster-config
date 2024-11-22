variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = "ghcr.io/"
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

job "owui-rag-sync" {
  datacenters = ["dc1"]
  type        = "batch"

  periodic {
    cron             = "0 * * * * *"
    prohibit_overlap = true
  }

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "owui-rag-sync"
    }

    task "app" {
      driver = "docker"

      vault {
        policies = ["service-owui-rag-sync"]
      }

      config {
        # entrypoint = ["sleep", "10000"]
        image = "${var.docker_registry}${var.image_id}"

        args = [
          "--bucket=${BUCKET}",
          "--endpoint=${ENDPOINT}",
          "--hours-since-modified=4"
        ]

      }
      template {
          destination = "secrets/app.env"
          env = true
          data = <<EOF

{{with secret "kv/data/owui-rag-sync"}}
AWS_ACCESS_KEY_ID={{.Data.data.AWS_ACCESS_KEY_ID}}
AWS_SECRET_ACCESS_KEY={{.Data.data.AWS_SECRET_ACCESS_KEY}}
BUCKET={{.Data.data.BUCKET}}
ENDPOINT=https://s3.{{ key "site/domain"}}

OPENWEBUI_URL="https://llm-web.{{key "site/domain"}}"
OPENWEBUI_BEARER_TOKEN={{.Data.data.OPENWEBUI_BEARER_TOKEN}}
OPENWEBUI_KNOWLEDGE_ID={{.Data.data.OPENWEBUI_KNOWLEDGE_ID}}
{{end}}


EOF
      }

      resources {
        cpu    = 125
        memory = 256
        memory_max = 256
      }

    }
  }
}
