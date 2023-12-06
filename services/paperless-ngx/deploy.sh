set -ex

vault policy write service-paperless-ngx policy.vault

# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars paperless-ngx.nomad
