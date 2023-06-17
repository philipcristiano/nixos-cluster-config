set -ex

vault policy write service-fasten policy.vault

#nomad volume create fasten.volume
nomad run fasten.nomad
