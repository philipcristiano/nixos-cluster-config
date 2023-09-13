set -ex

vault policy write service-mimir policy.vault

nomad run mimir.nomad
