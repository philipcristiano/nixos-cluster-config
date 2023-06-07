variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "postgres:15.3"
}

job "nostr-rs-relay-postgres" {
  datacenters = ["dc1"]
  type        = "service"

  group "db" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "nostr-rs-relay-postgres"
      port = "db"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.nostr-rs-relay-postgres.entrypoints=nostr-rs-relay-postgres",
        "traefik.tcp.routers.nostr-rs-relay-postgres.rule=HostSNI(`*`)",
      ]

      check {
        name     = "nostr-rs-relay-postgres"
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
      source          = "nostr-rs-relay-postgres"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"
      kill_timeout = "600s"

      config {
        image = var.image_id
        ports = ["db"]
        hostname = "nostr_rs_relay_postgres"
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
      	  destination = "secrets/pg"
          data = <<EOF
{{range ls "credentials/nostr-rs-relay-postgres"}}
POSTGRES_{{.Key}}={{.Value}}
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



