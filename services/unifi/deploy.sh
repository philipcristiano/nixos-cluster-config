set -ex

vault policy write service-unifi policy.vault

# nomad volume create unifi.volume
set -ex

SERVICE_ID=unifi
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
SOURCE_REGISTRY="$(awk '/FROM ./ {sub(/\/.*/, "", $2 ); print $2}' Dockerfile)/"

vault policy write "service-${SERVICE_ID}" policy.vault

nomad job dispatch -meta image="${IMAGE_ID}" -meta source_registry="${SOURCE_REGISTRY}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" "${SERVICE_ID}.nomad"
