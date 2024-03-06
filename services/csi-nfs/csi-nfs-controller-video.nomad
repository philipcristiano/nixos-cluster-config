variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = "registry.gitlab.com/"
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for the task."
}

job "storage-controller-video" {
  datacenters = ["dc1"]
  type        = "service"

  group "controller" {
    task "controller" {
      driver = "docker"

      config {
        image = "${var.docker_registry}${var.image_id}"

        args = [
          "--type=controller",
          "--node-id=${attr.unique.hostname}",
          "--nfs-server=192.168.1.212:/volume1/video", # Adjust accordingly
          "--mount-options=defaults", # Adjust accordingly
        ]

        network_mode = "host" # required so the mount works even after stopping the container

        privileged = true
      }

      csi_plugin {
        id        = "nfs-video" # Whatever you like, but node & controller config needs to match
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 50
        memory = 64
        memory_max = 256
      }

    }
  }
}
