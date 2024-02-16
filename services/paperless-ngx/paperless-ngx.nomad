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
  description = "The docker image used for task."
}

job "paperless-ngx" {
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
      name = "paperless-ngx"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.paperless-ngx.tls=true",
	      "traefik.http.routers.paperless-ngx.tls.certresolver=home",
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
  	    to = 8000
      }

    }

    volume "storage" {
      type            = "csi"
      source          = "paperless-ngx"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    ephemeral_disk {
      migrate = false
      size    = 500
      sticky  = false
    }

    task "prep-disk" {
      driver = "docker"
      volume_mount {
        volume      = "storage"
        destination = "/storage"
        read_only   = false
      }
      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R 1000:1000 /storage && chmod 775 /storage"]

      }
      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "docker-prepare" {
      driver = "docker"
      user = 1000

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      vault {
        policies = ["service-paperless-ngx"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        entrypoint = ["bash", "/local/docker_prepare.sh"]

      }

      volume_mount {
        volume      = "storage"
        destination = "/data/paperless"
      }

      resources {
        cpu    = 100
        memory = 256
        memory_max = 1024
      }

      template {
        env = true
        destination = "secrets/file.env"
        data = file("secrets.env.tmpl")
      }

      template {
        env = true
        destination = "local/file.env"
        data = file("env.tmpl")
      }

      template {
        destination = "local/docker_prepare.sh"
        perms = "655"
        data = file("docker-prepare.sh.tmpl")
      }

    }

    task "gunicorn" {
      driver = "docker"
      user = 1000

      vault {
        policies = ["service-paperless-ngx"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]

        entrypoint = ["gunicorn", "-c", "/usr/src/paperless/gunicorn.conf.py", "paperless.asgi:application"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data/paperless"
      }

      resources {
        cpu    = 10
        memory = 768
        memory_max = 1500
      }

      template {
        env = true
        destination = "secrets/file.env"
        data = file("secrets.env.tmpl")
      }

      template {
        env = true
        destination = "local/file.env"
        data = file("env.tmpl")
      }
    }

    task "document-consumer" {
      driver = "docker"
      user = 1000

      vault {
        policies = ["service-paperless-ngx"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        entrypoint = ["python3", "manage.py", "document_consumer"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data/paperless"
      }

      resources {
        cpu    = 10
        memory = 256
        memory_max = 512
      }

      template {
        env = true
        destination = "secrets/file.env"
        data = file("secrets.env.tmpl")
      }

      template {
        env = true
        destination = "local/file.env"
        data = file("env.tmpl")
      }
    }

    task "celery-worker" {
      driver = "docker"
      user = 1000

      vault {
        policies = ["service-paperless-ngx"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        entrypoint = ["celery", "--app", "paperless", "worker", "--loglevel=DEBUG"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data/paperless"
      }

      resources {
        cpu    = 10
        memory = 256
        memory_max = 4096
      }

      template {
        env = true
        destination = "secrets/file.env"
        data = file("secrets.env.tmpl")
      }

      template {
        env = true
        destination = "local/file.env"
        data = file("env.tmpl")
      }

      service {
        name = "paperless-ngx-celery"

        check {
          name     = "celery-worker"
          type     = "script"
          task     = "celery-worker"
          command     = "celery"
          args        = [
              "-A",
              "paperless",
              "inspect",
              "ping",
          ]
          interval = "60s"
          timeout  = "45s"
        }
        check_restart {
          limit = 3
          grace = "90s"
          ignore_warnings = false
        }
      }

    }

    task "celery-beat" {
      driver = "docker"
      user = 1000

      vault {
        policies = ["service-paperless-ngx"]
      }

      config {
        image = "${var.docker_registry}${var.image_id}"

        entrypoint = ["celery", "--app", "paperless", "beat", "--loglevel=INFO"]
      }

      volume_mount {
        volume      = "storage"
        destination = "/data/paperless"
      }

      resources {
        cpu    = 10
        memory = 256
        memory_max = 512
      }

      template {
        env = true
        destination = "secrets/file.env"
        data = file("secrets.env.tmpl")
      }

      template {
        env = true
        destination = "local/file.env"
        data = file("env.tmpl")
      }
    }
  }
}
