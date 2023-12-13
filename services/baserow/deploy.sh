set -ex

vault policy write service-baserow policy.vault

nomad run -var-file=../../nomad_job.vars baserow.nomad
