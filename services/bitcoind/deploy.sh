set -ex

vault policy write service-bitcoin policy.vault

#nomad volume create bitcoind.volume
nomad run bitcoind.nomad
