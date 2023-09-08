set -ex

vault policy write service-loki policy.vault

nomad run loki.nomad
