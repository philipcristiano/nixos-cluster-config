set -ex

vault policy write service-neon policy.vault

nomad run -var-file=../../nomad_job.vars neon.nomad
