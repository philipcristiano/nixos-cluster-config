set -ex

vault policy write service-folio policy.vault

#nomad volume create folio-postgres.volume
nomad run folio-postgres-backup.nomad
nomad run folio-postgres.nomad
nomad run folio.nomad
