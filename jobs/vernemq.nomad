job "vernemq" {
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
      name = "vernemq-mqtt"
      port = "mqtt"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.vernemq.entrypoints=mqtt",
        "traefik.tcp.routers.vernemq.rule=HostSNI(`*`)",
      ]

      check {
        name     = "vernemq-mqtt"
        type     = "tcp"
        port     = "mqtt"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "mqtt" {
  	    to = 1883
      }
    }

    #volume "storage" {
    #  type            = "csi"
    #  source          = "vernemq"
    #  read_only       = false
    #  attachment_mode = "file-system"
    #  access_mode     = "multi-node-multi-writer"
    #}

    task "app" {
      driver = "docker"

      config {
        image = "vernemq/vernemq:1.12.3-alpine"
        ports = ["mqtt"]
        hostname = "vernmq01"
      }

      env {
        DOCKER_VERNEMQ_ACCEPT_EULA = "yes"
      }
      template {
          env = true
      	  destination = "local/pwds"
          data = <<EOF
{{range ls "mqtt/credentials"}}
DOCKER_VERNEMQ_USER_{{.Key}}={{.Value}}
{{end}}
          EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }

    }
  }
}



