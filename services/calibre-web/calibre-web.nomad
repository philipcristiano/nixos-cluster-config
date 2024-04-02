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
  default     = "linuxserver/calibre-web:0.6.21"
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


    network {
      port "http" {
	to = 8083
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
        image        = "busybox:latest"
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
  }
}



