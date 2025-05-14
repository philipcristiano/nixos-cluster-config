set -ex

SERVICE_ID=grafana
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
IMAGE_RENDERER_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.image-renderer)

MATRIX_IMAGE_ID=$(awk '/FROM ./ {sub(/.[^\/]*\//, "", $2 ); print $2}' Dockerfile.matrix)
MATRIX_SOURCE_REGISTRY="$(awk '/FROM ./ {sub(/\/.*/, "", $2 ); print $2}' Dockerfile.matrix)/"
vault policy write service-grafana policy.vault

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${IMAGE_RENDERER_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${MATRIX_IMAGE_ID}" -meta source_registry="${MATRIX_SOURCE_REGISTRY}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
#nomad volume create grafana.volume
nomad run -var-file=../../nomad_job.vars -var="image_id=${IMAGE_ID}" grafana.nomad
nomad run -var-file=../../nomad_job.vars -var="image_id=${IMAGE_RENDERER_IMAGE_ID}" grafana-image-renderer.nomad
