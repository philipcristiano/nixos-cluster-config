set -ex

vault policy write service-directus policy.vault

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars directus.nomad
