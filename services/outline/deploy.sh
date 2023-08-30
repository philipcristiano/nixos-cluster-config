set -ex

vault policy write service-outline policy.vault

# nomad volume create outline-postgres.volume

nomad run outline-postgres-backup.nomad
nomad run outline-postgres.nomad
nomad run outline-redis.nomad
nomad run outline.nomad
