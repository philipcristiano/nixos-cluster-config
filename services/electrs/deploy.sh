set -ex

vault policy write service-electrs policy.vault

nomad run -var-file=../../nomad_job.vars electrs.nomad
