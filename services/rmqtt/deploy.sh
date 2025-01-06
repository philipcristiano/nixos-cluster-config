set -ex

SERVICE_ID=rmqtt
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

vault policy write service-${SERVICE_ID} policy.vault

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var="image_id=${IMAGE_ID}" -var-file=../../nomad_job.vars ${SERVICE_ID}.nomad
