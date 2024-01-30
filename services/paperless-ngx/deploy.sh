set -ex

vault policy write service-paperless-ngx policy.vault

pushd ../neon-compute
bash deploy.sh paperless-ngx
popd

pushd ../redis
bash deploy.sh paperless-ngx
popd

# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars paperless-ngx.nomad
