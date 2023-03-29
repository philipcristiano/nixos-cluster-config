job "tika" {
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
      name = "tika"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.tika.tls=true",
	      "traefik.http.routers.tika.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
  	    to = 9998
      }

    }

    task "app" {
      driver = "docker"

      config {
        image = "apache/tika:2.6.0.1-full"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]

      }


      resources {
        cpu    = 500
        memory = 512
      }

      env {}

    }
  }
}
