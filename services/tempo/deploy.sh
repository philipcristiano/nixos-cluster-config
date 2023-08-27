set -ex

vault policy write service-tempo policy.vault

# nomad volume create tempo.volume
nomad run tempo.nomad
