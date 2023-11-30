set -ex

vault policy write service-telegraf-prometheus policy.vault

nomad run -var-file=../../nomad_job.vars telegraf-prometheus.nomad
