set -ex

vault policy write service-hvac-iot policy.vault

SERVICE_ID=hvac-iot
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" hvac-iot.nomad
