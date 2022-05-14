job "mktxp-router" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "mktxp-router"
      port = "http"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.mktxp-router.tls=true",
	"traefik.http.routers.mktxp-router.tls.certresolver=home",
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
  	to = 49090
      }

    }

    task "app" {
      driver = "docker"

      config {
        image = "philipcristiano/mktxp:main@sha256:a1cd4cde25a28487d6f1ccbe1eb39b85c617979b28bf362c5686cd369b55e938"
        ports = ["http"]
        volumes = [
          "local/mktxp.conf:/root/mktxp/mktxp.conf",
        ]
      }

      resources {
        cpu    = 500
        memory = 256
      }
     template {
        data = <<EOTC
[Router]
    enabled = True         # turns metrics collection for this RouterOS device on / off

    hostname = 192.168.1.1    # RouterOS IP address
    port = 8728             # RouterOS IP Port

    username = {{key "credentials/mktxp/username" }}     # RouterOS user, needs to have 'read' and 'api' permissions
    password = {{key "credentials/mktxp/password" }}

    use_ssl = False                 # enables connection via API-SSL servis
    no_ssl_certificate = False      # enables API_SSL connect without router SSL certificate
    ssl_certificate_verify = False  # turns SSL certificate verification on / off

    dhcp = True                     # DHCP general metrics
    dhcp_lease = True               # DHCP lease metrics
    pool = True                     # Pool metrics
    interface = True                # Interfaces traffic metrics
    firewall = True                 # Firewall rules traffic metrics
    monitor = True                  # Interface monitor metrics
    poe = False                      # POE metrics
    route = True                    # Routes metrics
    wireless = False                 # WLAN general metrics
    wireless_clients = False         # WLAN clients metrics
    capsman = False                  # CAPsMAN general metrics
    capsman_clients = False          # CAPsMAN clients metrics

    use_comments_over_names = True  # when available, forces using comments over the interfaces names
EOTC
        destination = "local/mktxp.conf"
      }

    }
  }
}
