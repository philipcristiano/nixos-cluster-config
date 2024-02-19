variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = ""
}
variable "image_id" {
  type        = string
  description = "The docker image used for lnd."
}

job "llm" {
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
      name = "llm"
      port = "http"

      tags = [
        "prometheus",
        "traefik.enable=true",
	      "traefik.http.routers.llm.tls=true",
	      "traefik.http.routers.llm.tls.certresolver=home",
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
    service {
      name = "openai"
      port = "openai"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.openai.tls=true",
	      "traefik.http.routers.openai.tls.certresolver=home",
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
  	    to = 7860
      }
      port "openai" {
  	    to = 5000
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "llm"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http", "openai"]
        args  = [
          "python",
          "server.py",
          "--listen",
          "--verbose",
          "--model-dir=/storage/models",
          "--model=laser-dolphin-mixtral-2x7b-dpo.Q4_K_M.gguf",
          "--n_ctx=256000",
          "--settings", "/storage/settings.yaml",
        ]


      }

      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      resources {
        cpu    = 4000
        memory = 15000
        memory_max = 20000
      }
      env {
          EXTRA_LAUNCH_ARGS="--listen --verbose --extensions superboogav2 --model=mistral-7b-instruct-v0.2.Q6_K.gguf"
      }
    }
  }
}
