variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "dessalines/lemmy:0.17.4"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "lemmy" {
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
      name = "lemmy"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.lemmy.tls=true",
        "traefik.http.routers.lemmy.entrypoints=http,https,http-public,https-public",
	      "traefik.http.routers.lemmy.tls.certresolver=home",

        "traefik.http.routers.lemmy.rule=(Host(`lemmy.philipcristiano.com`) || Host(`lemmy.home.cristiano.cloud`)) && ( Method(`POST`) || HeaderRegexp(`Accept`, `(?i)^application/.*$`) || PathRegexp(`^/(api|pictrs|feeds|nodeinfo|.well-known).*`))",
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
  	    to = 8536
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
          destination = "secrets/lemmy.hjson"
          data = <<EOF
{
  # settings related to the postgresql database
  database: {
    # Username to connect to postgres
    user: "{{ key "credentials/lemmy-postgres/USER" }}"
    # Password to connect to postgres
    password: "{{ key "credentials/lemmy-postgres/PASSWORD" }}"
    # Host where postgres is running
    host: "lemmy-postgres.{{ key "site/domain" }}"
    # Port where postgres can be accessed
    port: {{ key "traefik-ports/lemmy-postgres" }}
    # Name of the postgres database for lemmy
    database: "{{ key "credentials/lemmy-postgres/DB" }}"
    # Maximum number of active sql connections
    pool_size: 5
  }

  # Settings related to activitypub federation
  # Pictrs image server configuration.
  pictrs: {
    # Address where pictrs is available (for image hosting)
    url: "https://pictrs.{{ key "site/domain"}}/"
    # Set a custom pictrs API key. ( Required for deleting images )
    api_key: "string"
  }
  # Email sending configuration. All options except login/password are mandatory
  email: {
    # Hostname and port of the smtp server
    smtp_server: "localhost:25"
    # Login name for smtp server
    smtp_login: "string"
    # Password to login to the smtp server
    smtp_password: "string"
    # Address to send emails from, eg "noreply@your-instance.com"
    smtp_from_address: "noreply@example.com"
    # Whether or not smtp connections should use tls. Can be none, tls, or starttls
    tls_type: "none"
  }
  # Parameters for automatic configuration of new instance (only used at first start)
  setup: {
    # Username for the admin user
    admin_username: "admin"
    # Password for the admin user. It must be at least 10 characters.
    admin_password: "tf6HHDS4RolWfFhk4Rq9"
    # Name of the site (can be changed later)
    site_name: "My Lemmy Instance"
    # Email for the admin user (optional, can be omitted and set later through the website)
    admin_email: "user@example.com"
  }
  # the domain name of your instance (mandatory)
  hostname: "lemmy.{{ key "site/public_domain"}}"
  # Address where lemmy should listen for incoming requests
  bind: "0.0.0.0"
  # Port where lemmy should listen for incoming requests
  port: 8536
  # Whether the site is available over TLS. Needs to be true for federation to work.
  tls_enabled: true
}


EOF
      }
    }
  }
}



