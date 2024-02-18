set -ex

vault policy write service-miniflux policy.vault


SERVICE_ID=miniflux
IMAGE_ID=$(awk '/FROM ./ {sub(/.[^\/]*\//, "", $2 ); print $2}' Dockerfile)
SOURCE_REGISTRY="$(awk '/FROM ./ {sub(/\/.*/, "", $2 ); print $2}' Dockerfile)/"

pushd ../neon-compute
bash deploy.sh miniflux
popd

nomad job dispatch -meta image="${IMAGE_ID}" -meta source_registry="${SOURCE_REGISTRY}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}"  miniflux.nomad
