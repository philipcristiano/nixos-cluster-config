job "mattermost-postgres" {
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
      name = "mattermost-postgres"
      port = "db"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mattermost-postgres.entrypoints=mattermost-postgres",
        "traefik.tcp.routers.mattermost-postgres.rule=HostSNI(`*`)",
      ]

      check {
        name     = "mattermost-postgres"
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
      source          = "mattermost-postgres"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "postgres:14.6"
        ports = ["db"]
        hostname = "mattermost_postgres"
      }

      volume_mount {
        volume      = "storage"
        destination = "/var/lib/postgresql/data/"
      }

      env {}

      template {
          env = true
      	  destination = "secrets/pg"
          data = <<EOF
{{range ls "credentials/mattermost-postgres"}}
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



