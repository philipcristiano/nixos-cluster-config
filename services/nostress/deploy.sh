set -ex

vault policy write service-nostress policy.vault

nomad run -var=count=2 nostress.nomad
