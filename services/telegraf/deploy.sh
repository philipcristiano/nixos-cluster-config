set -ex

vault policy write service-telegraf-prometheus policy.vault

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars telegraf-system.nomad
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars telegraf-influxdb-input.nomad
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars telegraf-prometheus.nomad
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars telegraf-dc.nomad
