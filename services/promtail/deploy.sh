set -ex

vault policy write service-loki policy.vault

nomad run -var-file=../../nomad_job.vars promtail.nomad
