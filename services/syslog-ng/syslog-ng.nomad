variable "syslog_image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "balabit/syslog-ng:4.2.0"
}

variable "promtail_image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "grafana/promtail:2.8.4"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "syslog-ng" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "syslog-udp"
      port = "syslog-udp"

      tags = [
        "traefik.enable=true",
        "traefik.udp.routers.syslog-udp.entrypoints=syslog-udp",
      ]

    }
    service {
      name = "syslog-promtail"
      port = "promtail"
      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.syslog-promtail.tls=true",
	      "traefik.http.routers.syslog-promtail.tls.certresolver=home",
      ]

      check {
        name     = "Promtail HTTP"
        type     = "http"
        port     = "promtail"
        path     = "/targets"
        interval = "5s"
        timeout  = "2s"

      }
    }


    network {
      mode = "bridge"

      port "syslog-udp" {
  	    to = 514
      }

      port "promtail" {
  	    to = 8080
      }
    }

    task "syslog" {
      driver = "docker"

      config {
        image = var.syslog_image_id
        ports = ["syslog-udp"]
        # entrypoint = ["sleep", "10000"]

        mount {
          type     = "bind"
          source   = "local/syslog.conf"
          target   = "/etc/syslog-ng/syslog-ng.conf"
          readonly = true
        }

      }

      resources {
        cpu    = 50
        memory = 32
        memory_max = 512
      }

      template {
        destination = "local/syslog.conf"
        data = <<EOF

@version: 4.2
@include "scl.conf"

source s_local {
	internal();
};

source s_network {
	default-network-drivers(
		# NOTE: TLS support
		#
		# the default-network-drivers() source driver opens the TLS
		# enabled ports as well, however without an actual key/cert
		# pair they will not operate and syslog-ng would display a
		# warning at startup.
		#
		#tls(key-file("/path/to/ssl-private-key") cert-file("/path/to/ssl-cert"))
	);
};

rewrite r_rewrite_set_appname {
  set("${PROGRAM}", value(".SDATA.custom@99770.appname"));
};

rewrite r_rewrite_unset{
  unset(value("PROGRAM"));
};

destination d_loki {
	syslog("127.0.0.1" transport("tcp") port("1515") flags(syslog-protocol));
};

log {
        source(s_local);
        source(s_network);

        rewrite(r_rewrite_set_appname);
        rewrite(r_rewrite_unset);

        destination(d_loki);
};



EOF

      }

    }

    task "promtail" {
      driver = "docker"

      env {
        HOSTNAME = "${attr.unique.hostname}"
      }
      template {
        data        = <<EOTC
positions:
  filename: /data/positions.yaml

clients:
  - url: https://loki.{{ key "site/domain" }}/loki/api/v1/push

scrape_configs:
- job_name: syslog
  syslog:
    listen_address: 127.0.0.1:1515
    idle_timeout: 600s
    label_structured_data: yes
    labels:
      job: "syslog"
    use_incoming_timestamp: true
  relabel_configs:
  - source_labels: ['__syslog_message_hostname']
    target_label: 'hostname'
  - source_labels: ['__syslog_message_severity']
    target_label: 'severity'
  - source_labels: ['__syslog_message_facility']
    target_label: 'facility'
  - source_labels: ['__syslog_message_app_name']
    target_label: 'appname'

EOTC
        destination = "/local/promtail.yml"
      }

      config {
        image = var.promtail_image_id
        ports = ["promtail"]
        args = [
          "-config.file=/local/promtail.yml",
          "-server.http-listen-port=${NOMAD_PORT_promtail}",
        ]
      }

      resources {
        cpu    = 50
        memory = 24
        memory_max = 128
      }

    }
  }
}



