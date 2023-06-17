set -ex

vault policy write service-mempool policy.vault
# nomad volume create mempool-mariadb.volume
nomad run mempool-mariadb.nomad
nomad run mempool.nomad
