job "gotenberg" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "gotenberg"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.gotenberg.tls=true",
	      "traefik.http.routers.gotenberg.tls.certresolver=home",
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
  	    to = 3000
      }

    }

    task "app" {
      driver = "docker"

      config {
        image = "docker.io/gotenberg/gotenberg:7.6"
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]

        command = "gotenberg"
        args = [
            "uno-listener-restart-threshold",
            "0",
        ]

      }


      resources {
        cpu    = 500
        memory = 512
      }

      env {}

    }
  }
}
