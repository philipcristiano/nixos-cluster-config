job "minio" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "s3"
      port = "api"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.s3.tls=true",
	      "traefik.http.routers.s3.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "api"
        interval = "10s"
        timeout  = "2s"
      }
    }
    service {
      name = "minio"
      port = "console"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.minio.tls=true",
	      "traefik.http.routers.minio.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "api"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "api" {
  	    to = 9000
      }
      port "console" {
        to = 9090
      }

    }
    volume "storage" {
      type            = "csi"
      source          = "minio"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "quay.io/minio/minio:RELEASE.2023-01-31T02-24-19Z"
        ports = ["api", "console"]
        command = "server"

        args = [
          "--console-address=:9090",
        ]

      }
      volume_mount {
        volume      = "storage"
        destination = "/storage"
      }

      resources {
        cpu    = 100
        memory = 512
      }

      env {
        MINIO_VOLUMES="/storage"
      }

      template {
        env = true
        data = <<EOF
MINIO_ROOT_USER = "{{key "credentials/minio/root_user"}}"
MINIO_ROOT_PASSWORD = "{{key "credentials/minio/root_pass"}}"
EOF
        destination = "secrets/file.env"
      }

    }
  }
}
