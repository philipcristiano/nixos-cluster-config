set -ex

vault policy write service-paperless-ngx policy.vault

# nomad volume create paperless-ngx.volume
nomad run redis-paperless-ngx.nomad
nomad run paperless-ngx.nomad
