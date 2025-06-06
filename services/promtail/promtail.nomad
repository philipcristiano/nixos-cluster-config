variable "docker_registry" {
  type        = string
  description = "The docker registry"
  default     = ""
}

variable "domain" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

job "promtail" {
  datacenters = ["dc1"]
  type = "system"

  group "promtail" {
    count = 1

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 3200
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
- job_name: 'nomad-logs'
  consul_sd_configs:
    - server: '172.17.0.1:8500'
  relabel_configs:
    - source_labels: [__meta_consul_node]
      target_label: __host__
    - source_labels: [__meta_consul_service_metadata_external_source]
      target_label: source
      regex: (.*)
      replacement: '$1'
    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
      target_label:  'task_id'
      replacement: '$1'
    - source_labels: [__meta_consul_tags]
      regex: ',(app|monitoring),'
      target_label:  'group'
      replacement:   '$1'
    - source_labels: [__meta_consul_service]
      target_label: service
    - source_labels: [__meta_consul_service]
      target_label: service_name
    - source_labels: ['__meta_consul_node']
      regex:         '(.*)'
      target_label:  'instance'
      replacement:   '$1'
    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
      target_label:  '__path__'
      replacement: '/nomad/alloc/$1/alloc/logs/*std*'
    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
      target_label:  '__path_exclude__'
      replacement: '/nomad/alloc/$1/alloc/logs/*fifo'

- job_name: 'system-journal'
  journal:
    json: false
    max_age: 12h
    path: /system-logs
    labels:
      job: systemd-journal
  relabel_configs:
    - source_labels: ["__journal__systemd_unit"]
      target_label: "unit"
    - source_labels: ["__journal__hostname"]
      target_label: host
    - source_labels: ["__journal_priority_keyword"]
      target_label: level
    - source_labels: ["__journal_syslog_identifier"]
      target_label: syslog_identifier

EOTC
        destination = "/local/promtail.yml"
      }

      config {
        image = "${var.docker_registry}${var.image_id}"
        ports = ["http"]
        args = [
          "-config.file=/local/promtail.yml",
          "-server.http-listen-port=${NOMAD_PORT_http}",
        ]
        volumes = [
          "/data/promtail:/data",
          "/var/lib/nomad:/nomad/",
          "/var/log/journal:/system-logs"
        ]
      }

      resources {
        cpu    = 50
        memory = 100
      }

      service {
        name = "promtail"
        port = "http"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Promtail HTTP"
          type     = "http"
          path     = "/targets"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}
