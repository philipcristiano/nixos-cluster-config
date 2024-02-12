set -ex

vault policy write service-postmoogle policy.vault

nomad run -var-file=../../nomad_job.vars postmoogle.nomad
