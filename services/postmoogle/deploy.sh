set -ex

vault policy write service-postmoogle policy.vault

nomad run postmoogle.nomad
