set -ex

vault policy write service-gocast policy.vault

nomad run -var-file=../../nomad_job.vars gocast.nomad
