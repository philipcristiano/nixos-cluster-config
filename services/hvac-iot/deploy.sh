set -ex

vault policy write service-hvac-iot policy.vault

nomad run hvac-iot.nomad
