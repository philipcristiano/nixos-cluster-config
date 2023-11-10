set -ex

vault policy write service-miniflux policy.vault

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars miniflux.nomad
