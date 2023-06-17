set -ex

vault policy write service-keycloak policy.vault

#nomad volume create keycloak-postgres.volume
nomad run keycloak-postgres-backup.nomad
nomad run keycloak-postgres.nomad
nomad run keycloak.nomad
