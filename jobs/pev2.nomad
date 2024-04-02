job "pev2" {
  datacenters = ["dc1"]

  group "nginx" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "pev2"
      port = "http"
      tags = [
        "traefik.enable=true",
	    "traefik.http.routers.pev2.tls=true",
	    "traefik.http.routers.pev2.tls.certresolver=home",
      ]

      check {
          name     = "alive"
          type     = "tcp"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
      }
    }

    task "download" {
      driver = "docker"
      config {
        image        = "curlimages/curl:8.00.1"
        args         = [
          "-L",
          "-o",
          "alloc/data/index.html",
          "https://github.com/dalibo/pev2/releases/download/v1.8.0/index.html",
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "nginx" {
      driver = "docker"


      config {
        image = "nginx"

        ports = ["http"]

        volumes = [
          "local/config:/etc/nginx/conf.d",
        ]
      }

      resources {
        cpu    = 10
        memory = 16
      }

      template {
        data = <<EOF

server {
   listen 8080;
   root /alloc/data ;

   location / {
   }
}
EOF

        destination   = "local/config/static.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}

