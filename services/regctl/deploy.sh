set -ex

vault policy write service-regctl policy.vault

nomad run -var-file=../../nomad_job.vars regctl.nomad
