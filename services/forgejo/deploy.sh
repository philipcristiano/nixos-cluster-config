set -ex

vault policy write service-forgejo policy.vault

# nomad volume create forgejo-postgres.volume
# nomad volume create forgejo.volume

nomad run forgejo-postgres.nomad
nomad run forgejo-postgres-backup.nomad
nomad run forgejo.nomad
