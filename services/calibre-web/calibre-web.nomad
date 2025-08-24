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

variable "metadata_api_image_id" {
  type        = string
  description = "The docker image used for metadata task."
}

job "calibre-web" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "calibre"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.calibre.tls=true",
	      "traefik.http.routers.calibre.tls.certresolver=home",
      ]

      check {
        name     = "http"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "calibre-metadata-api"
      port = "metadata-api"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.calibre-metadata-api.tls=true",
	      "traefik.http.routers.calibre-metadata-api.tls.certresolver=home",
      ]

      check {
        name     = "metadata-api-healthy"
        type     = "http"
        port     = "metadata-api"
        path     = "/_health"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
	      to = 8083
      }
      port "metadata-api" {
	      to = 3002
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "calibre-web"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "prep-disk" {
      driver = "docker"
      volume_mount {
        volume      = "storage"
        destination = "/storage"
        read_only   = false
      }
      config {
        image        = "${var.docker_registry}busybox/busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R 1000:0 /storage && chmod 775 /storage"]
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

    task "app" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 1000
        memory_max = 2000
      }

      env = {
        PUID=1000
        PGID=1000
        TZ="Etc/UTC"
        DOCKER_MODS="linuxserver/mods:universal-calibre"
      }

      volume_mount {
        volume      = "storage"
        destination = "/config/"
      }

      template {
	destination = "/etc/local-config.yaml"
        data =  <<EOF

EOF
      }

      template {
          destination = "local/ca.pem"
          data = <<EOF
{{- with secret "/pki/issuer/default/json" -}}
{{- .Data.certificate -}}
{{- end -}}
EOF
      }
    }

    task "metadata" {
      driver = "docker"

      vault {
        policies = ["service-calibre-web"]
      }

      config {
        image = "${var.docker_registry}${var.metadata_api_image_id}"
        ports = ["metadata-api"]
        # entrypoint = ["sleep", "10000"]
        args = [
          "--bind-addr", "0.0.0.0:3002",
          "--config-file", "/local/cma.toml",
          "--log-level", "DEBUG",
        ]
      }

      resources {
        cpu    = 50
        memory = 128
        memory_max = 512
      }

      template {
	      destination = "/local/cma.toml"
        data =  <<EOF
database_url = "/config/books/metadata.db"

EOF
      }

      volume_mount {
        volume      = "storage"
        destination = "/config/"
      }

      template {
      	  destination = "local/otel.env"
          env = true
          data = file("../template_fragments/otel_grpc.env.tmpl")
      }

    }
  }
}



