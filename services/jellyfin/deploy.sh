set -ex

vault policy write service-jellyfin policy.vault

SERVICE_ID=jellyfin
IMAGE_ID=$(awk '/FROM ./ {sub(/.[^\/]*\//, "", $2 ); print $2}' Dockerfile)
SOURCE_REGISTRY="$(awk '/FROM ./ {sub(/\/.*/, "", $2 ); print $2}' Dockerfile)/"

nomad job dispatch -meta image="${IMAGE_ID}" -meta source_registry="${SOURCE_REGISTRY}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" jellyfin.nomad
