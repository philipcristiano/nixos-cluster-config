set -ex

vault policy write service-forgejo policy.vault

nomad run -var-file=../../nomad_job.vars forgejo.nomad
