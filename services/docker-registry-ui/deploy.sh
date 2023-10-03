set -ex

vault policy write service-docker-registry-ui policy.vault
nomad run -var-file=../../nomad_job.vars docker-registry-ui.nomad
