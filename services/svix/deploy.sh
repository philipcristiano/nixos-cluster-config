set -ex

vault policy write service-svix policy.vault

#nomad volume create svix-postgres.volume
nomad run svix-postgres.nomad
nomad run svix-postgres-backup.nomad
nomad run svix-redis.nomad
nomad run svix.nomad
