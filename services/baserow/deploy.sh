set -ex

vault policy write service-baserow policy.vault

#nomad volume create baserow-postgres.volume
nomad run baserow-postgres.nomad
nomad run baserow-redis.nomad
nomad run baserow.nomad
