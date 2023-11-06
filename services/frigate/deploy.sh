set -ex

vault policy write service-frigate policy.vault

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars frigate.nomad
