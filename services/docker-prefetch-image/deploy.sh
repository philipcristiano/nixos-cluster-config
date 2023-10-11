set -ex

vault policy write service-docker-prefetch-image policy.vault

nomad run -var-file=../../nomad_job.vars docker-prefetch-image.nomad
