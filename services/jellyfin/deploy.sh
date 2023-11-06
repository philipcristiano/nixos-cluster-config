set -ex

vault policy write service-jellyfin policy.vault

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars jellyfin.nomad
