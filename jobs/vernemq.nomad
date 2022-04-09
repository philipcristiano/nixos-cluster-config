job "vernemq" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "vernemq-mqtt"
      port = "mqtt"

      # tags = [
      #   "traefik.enable=true",
      #   "traefik.http.routers.emqx.tls=true",
      #   "traefik.http.routers.emqx.tls.certresolver=home",
      # ]

      check {
        name     = "alive"
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
	DOCKER_VERNEMQ_ALLOW_ANONYMOUS = "on"
	VERNEMQ_CONF_LOCAL_FILE = "/local/vernemq.conf"
      }
      template {
          data = <<EOF
          EOF

      	  destination = "local/vernqmq.conf"
      }

      # volume_mount {
      #   volume      = "storage"
      #   destination = "/opt/emqx/data/mnesia"
      # }

      resources {
        cpu    = 500
        memory = 512
      }

    }
  }
}



