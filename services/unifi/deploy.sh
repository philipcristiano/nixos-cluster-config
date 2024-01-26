set -ex

vault policy write service-unifi policy.vault

# nomad volume create unifi.volume
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars unifi.nomad
