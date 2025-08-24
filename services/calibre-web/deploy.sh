set -ex

SERVICE_ID=calibre-web
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
METADATA_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.metadata)

vault policy write "service-${SERVICE_ID}" policy.vault
volume create ${SERVICE_ID}.volume || true

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${METADATA_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" -var "metadata_api_image_id=${METADATA_IMAGE_ID}" "${SERVICE_ID}.nomad"
