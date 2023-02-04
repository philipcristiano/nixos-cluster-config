job "mktxp-office" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    service {
      name = "mktxp-office"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.mktxp-office.tls=true",
        "traefik.http.routers.mktxp-office.tls.certresolver=home",
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
      mode = "bridge"
      port "http" {
    to = 49090
      }

    }

    task "app" {
      driver = "docker"

      config {
        image = "ghcr.io/akpw/mktxp:stable-20230117072202"
        ports = ["http"]
        volumes = [
          "local/mktxp.conf:/root/mktxp/mktxp.conf",
        ]
      }

      resources {
        cpu    = 50
        memory = 128
      }
     template {
        data = <<EOTC
[Office]
    enabled = True         # turns metrics collection for this RouterOS device on / off

    hostname = 192.168.1.105    # RouterOS IP address
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
