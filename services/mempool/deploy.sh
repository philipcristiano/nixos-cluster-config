set -ex

SERVICE_ID=mempool
FE_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.frontend)
BE_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.backend)
DB_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.mariadb)

vault policy write "service-${SERVICE_ID}" policy.vault

# nomad volume create mempool-mariadb.volume

nomad job dispatch -meta image="${FE_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${BE_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${DB_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${DB_IMAGE_ID}" "${SERVICE_ID}-mariadb.nomad"
nomad run -var-file=../../nomad_job.vars -var "frontend_image_id=${FE_IMAGE_ID}" -var "backend_image_id=${BE_IMAGE_ID}" "${SERVICE_ID}.nomad"
