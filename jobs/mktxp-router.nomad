job "mktxp-router" {
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
      name = "mktxp-router"
      port = "http"

      tags = [
        "traefik.enable=true",
	"traefik.http.routers.mktxp-router.tls=true",
	"traefik.http.routers.mktxp-router.tls.certresolver=home",
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
      mode = "bridge"
      port "http" {
  	    to = 49090
      }

    }

    task "app" {
      driver = "docker"

      config {
        image = "ghcr.io/akpw/mktxp:stable-20230706091740"
        ports = ["http"]
        volumes = [
          "local/mktxp.conf:/root/mktxp/mktxp.conf",
        ]

        entrypoint = [
          "/usr/local/bin/mktxp",
          "--cfg-dir",
          "/local",
          "export",
        ]
      }

      resources {
        cpu    = 50
        memory = 128
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

    installed_packages = True       # Installed packages
    dhcp = True                     # DHCP general metrics
    dhcp_lease = True               # DHCP lease metrics
    connections = True              # IP connections metrics
    pool = True                     # Pool metrics
    interface = True                # Interfaces traffic metrics

    firewall = True                 # IPv4 Firewall rules traffic metrics
    ipv6_firewall = False           # IPv6 Firewall rules traffic metrics
    ipv6_neighbor = False           # Reachable IPv6 Neighbors

    poe = False                     # POE metrics
    monitor = True                  # Interface monitor metrics
    netwatch = True                 # Netwatch metrics
    public_ip = True                # Public IP metrics
    route = True                    # Routes metrics
    wireless = True                 # WLAN general metrics
    wireless_clients = True         # WLAN clients metrics
    capsman = True                  # CAPsMAN general metrics
    capsman_clients = True          # CAPsMAN clients metrics

    user = True                     # Active Users metrics
    queue = True                    # Queues metrics

    remote_dhcp_entry = None        # An MKTXP entry for remote DHCP info resolution in capsman/wireless

    use_comments_over_names = True  # when available, forces using comments over the interfaces names
EOTC
        destination = "local/mktxp.conf"
      }
    }

    task "telegraf" {
      driver = "docker"
      config {
        image        = "telegraf:1.25.1"
        force_pull   = true
        entrypoint   = ["telegraf"]
        args = [
          "-config",
          "/local/telegraf.conf",
        ]
      }

      template {
        data = <<EOTC
# Adding Client class
# This should be here until https://github.com/hashicorp/nomad/pull/3882 is merged
{{ $node_class := env "node.class" }}
[global_tags]
nomad_client_class = "{{ env "node.class" }}"

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "3s"
  precision = ""
  debug = false
  quiet = false
  hostname = ""
  omit_hostname = false

[[outputs.influxdb_v2]]
  urls = ["https://influxdb.{{ key "site/domain" }}"]
  bucket = "host"
  organization = "{{key "credentials/mktxp/influxdb_organization"}}"
  token = "{{key "credentials/mktxp/influxdb_token"}}"

[[outputs.http]]
  ## URL is the address to send metrics to
  url = "https://mimir.{{ key "site/domain" }}/api/v1/push"

  ## Optional TLS Config
  # tls_ca = "/etc/telegraf/ca.pem"
  # tls_cert = "/etc/telegraf/cert.pem"
  # tls_key = "/etc/telegraf/key.pem"

  ## Data format to output.
  data_format = "prometheusremotewrite"

  [outputs.http.headers]
     Content-Type = "application/x-protobuf"
     Content-Encoding = "snappy"
     X-Prometheus-Remote-Write-Version = "0.1.0"


[[inputs.prometheus]]
  metric_version = 2
  urls = ["http://127.0.0.1:{{ env "NOMAD_PORT_http" }}/metrics"]

EOTC
        destination = "local/telegraf.conf"
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
