set -ex

vault policy write service-nostress policy.vault

SERVICE_ID=nostress
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" nostress.nomad
