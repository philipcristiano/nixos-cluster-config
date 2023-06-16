variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "dessalines/lemmy-ui:0.17.4"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "lemmy-ui" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"

      auto_promote     = true
      canary           = 1
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "lemmy-ui"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.lemmy-ui.tls=true",
        "traefik.http.routers.lemmy-ui.entrypoints=http,https,http-public,https-public",
	      "traefik.http.routers.lemmy-ui.tls.certresolver=home",
        "traefik.http.routers.lemmy-ui.rule=(Host(`lemmy.philipcristiano.com`) || Host(`lemmy.home.cristiano.cloud`)) && !( Method(`POST`) || HeaderRegexp(`Accept`, `(?i)^application/.*$`) || PathRegexp(`^/(api|pictrs|feeds|nodeinfo|.well-known).*`))",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    network {
      port "http" {
  	    to = 1234
      }
    }

    task "app" {
      driver = "docker"
      user = 1000

      config {
        image = var.image_id
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]
      }

      resources {
        cpu    = 100
        memory = 512
        memory_max = 1024
      }

      env = {
        LEMMY_CONFIG_LOCATION = "/secrets/lemmy.hjson"
        RUST_BACKTRACE = 1
      }

      template {
          destination = "local/lemmy-ui.env"
          env = true
          data = <<EOF

LEMMY_UI_LEMMY_INTERNAL_HOST="lemmy.{{ key "site/domain"}}"
LEMMY_UI_LEMMY_EXTERNAL_HOST="lemmy.{{ key "site/public_domain"}}"
LEMMY_UI_HTTPS=true

EOF

      }

    }
  }
}



