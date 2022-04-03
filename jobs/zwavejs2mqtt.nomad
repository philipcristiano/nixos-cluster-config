job "zwavejs2mqtt" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    volume "storage" {
      type            = "csi"
      source          = "zwavejs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = "zwavejs/zwavejs2mqtt:6.2.0"

      }

      volume_mount {
        volume      = "storage"
        destination = "/usr/src/app/store"
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}


