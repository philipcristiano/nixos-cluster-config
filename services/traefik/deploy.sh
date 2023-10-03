set -ex

vault policy write service-traefik policy.vault

# nomad volume create minio.volume

nomad run -var-file=../../nomad_job.vars traefik.nomad
