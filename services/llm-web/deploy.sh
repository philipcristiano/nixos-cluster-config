set -ex


SERVICE_ID=llm-web
IMAGE_ID=$(awk '/FROM ./ {sub(/.[^\/]*\//, "", $2 ); print $2}' Dockerfile)
SOURCE_REGISTRY="$(awk '/FROM ./ {sub(/\/.*/, "", $2 ); print $2}' Dockerfile)/"

vault policy write service-${SERVICE_ID} policy.vault

nomad volume create ${SERVICE_ID}.volume || true
nomad volume create ollama.volume || true
nomad job dispatch -meta image="${IMAGE_ID}" -meta source_registry="${SOURCE_REGISTRY}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" ${SERVICE_ID}.nomad
