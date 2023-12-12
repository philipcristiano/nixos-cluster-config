set -ex

vault policy write service-mimir policy.vault

nomad run -var-file=../../nomad_job.vars mimir.nomad
