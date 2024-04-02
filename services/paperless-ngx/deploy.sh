set -ex

vault policy write service-paperless-ngx policy.vault

SERVICE_ID=paperless-ngx
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

pushd ../postgres
bash deploy.sh paperless-ngx
popd

pushd ../redis
bash deploy.sh paperless-ngx
popd

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" paperless-ngx.nomad
