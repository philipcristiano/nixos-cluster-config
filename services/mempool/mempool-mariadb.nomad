variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Name of this instance of Neon Compute Postgres"
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

job "mempool-mariadb" {
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
      name = "mempool-mariadb"
      port = "db"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mempool-mariadb.entrypoints=mempool-mariadb",
        "traefik.tcp.routers.mempool-mariadb.rule=HostSNI(`*`)",
      ]

      check {
        name     = "mempool-mariadb"
        type     = "tcp"
        port     = "db"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "db" {
  	    to = 3306
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "mempool-mariadb"
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
        image        = "${var.docker_registry}busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage/data && chown -R 999:999 /storage && chmod 775 /storage"]
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
        ports = ["db"]
        hostname = "mempool-mariadb"
      }

      volume_mount {
        volume      = "storage"
        destination = "/var/lib/mysql"
      }

      env {}

      template {
          env = true
      	  destination = "secrets/mariadb"
          data = <<EOF
{{range ls "credentials/mempool-mariadb"}}
MARIADB_{{.Key}}={{.Value}}
{{end}}
          EOF
      }

      resources {
        cpu    = 128
        memory = 512
      }

    }
  }
}



