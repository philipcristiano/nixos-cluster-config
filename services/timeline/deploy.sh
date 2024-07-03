set -ex

SERVICE_ID=timeline
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

vault policy write service-${SERVICE_ID} policy.vault

pushd ../postgres
bash deploy.sh timeline
popd

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" "${SERVICE_ID}.nomad"
