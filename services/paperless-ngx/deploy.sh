set -ex

vault policy write service-paperless-ngx policy.vault

# nomad volume create paperless-ngx.volume
nomad run paperless-ngx-redis.nomad
nomad run paperless-ngx.nomad
