job "keycloak-postgres" {
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
      name = "keycloak-postgres"
      port = "db"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.keycloak-postgres.entrypoints=keycloak-postgres",
        "traefik.tcp.routers.keycloak-postgres.rule=HostSNI(`*`)",
      ]

      check {
        name     = "keycloak-postgres"
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
      source          = "keycloak-postgres"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "postgres:14.6"
        ports = ["db"]
        hostname = "keycloak_postgres"
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
{{range ls "credentials/keycloak-postgres"}}
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



