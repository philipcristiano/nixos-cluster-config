set -ex

vault policy write service-lightning-network-daemon policy.vault
vault policy write service-lightning-terminal policy.vault
# nomad volume create lightning-network-daemon.volume
nomad run -var-file=../../nomad_job.vars lightning-network-daemon.nomad
