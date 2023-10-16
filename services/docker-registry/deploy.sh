set -ex

vault policy write service-docker-registry policy.vault

# nomad volume create minio.volume

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars docker-registry.nomad
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars docker-registry-garbage-collect.nomad
