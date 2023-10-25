set -ex

vault policy write service-bitcoin policy.vault

#nomad volume create bitcoind.volume
nomad run -var-file=../../nomad_job.vars bitcoind.nomad
