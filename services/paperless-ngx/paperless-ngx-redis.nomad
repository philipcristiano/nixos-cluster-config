
variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "redis:7.0.11"
}

job "paperless-ngx-redis" {

  datacenters = ["dc1"]

  type = "service"

  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert = false
    canary = 0
  }

  group "cache" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"

      delay = "25s"

      mode = "delay"
    }

    network {
      port "db" {
  	    to = 6379
      }
    }


    ephemeral_disk {

     size = 300
   }

    task "redis" {
      driver = "docker"

      config {
        image = var.image_id
        ports = ["db"]
        args = ["/secrets/redis.conf"]
      }

      resources {
        cpu    = 50
        memory = 24
        memory_max = 512
      }

      service {
        name = "paperless-ngx-redis"
        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.paperless-ngx-redis.entrypoints=paperless-ngx-redis",
          "traefik.tcp.routers.paperless-ngx-redis.rule=HostSNI(`*`)",
        ]

        port = "db"
        check {
          name     = "paperless-ngx-redis"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        data          = <<EOF

masteruser default
requirepass {{ key "credentials/paperless-ngx-redis/password" }}

loglevel verbose

EOF
        destination   = "secrets/redis.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}

