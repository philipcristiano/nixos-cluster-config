set -ex

vault policy write service-nomad-events-logger policy.vault

nomad run nomad-events-logger.nomad
