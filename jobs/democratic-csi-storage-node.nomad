job "storage-node" {
  datacenters = ["dc1"]
  type        = "system"

  group "node" {
    task "node" {
      driver = "docker"

      config {
        image = "democraticcsi/democratic-csi:v1.5.4"

        args = [
          "--csi-version=1.2.0",
          "--csi-name=org.democratic-csi.node-manual",
          "--driver-config-file=${NOMAD_TASK_DIR}/driver-config-file.yaml",
          "--log-level=debug",
          "--csi-mode=node",
          "--server-socket=/csi-data/csi.sock",
        ]

        privileged = true
      }

      csi_plugin {
        id        = "org.democratic-csi.node-manual"
        type      = "node"
        mount_dir = "/csi-data"
      }

      template {
        destination = "${NOMAD_TASK_DIR}/driver-config-file.yaml"

        data = <<EOH
driver: node-manual
EOH
      }

      resources {
        cpu    = 30
        memory = 50
      }
    }
  }
}
