set -ex

vault policy write service-minio policy.vault

# nomad volume create minio.volume

nomad run minio.nomad
