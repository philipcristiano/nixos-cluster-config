set -ex

vault policy write service-hello-idc policy.vault

nomad run hello_idc.nomad
