set -ex

vault policy write service-ytdl-sub policy.vault

SERVICE_ID=ytdl-sub
IMAGE_ID=$(awk '/FROM ./ {sub(/.[^\/]*\//, "", $2 ); print $2}' Dockerfile)
SOURCE_REGISTRY="$(awk '/FROM ./ {sub(/\/.*/, "", $2 ); print $2}' Dockerfile)/"


# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume
#
nomad job dispatch -meta image="${IMAGE_ID}" -meta source_registry="${SOURCE_REGISTRY}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" ytdl-sub.nomad
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" ytdl-sub-once.nomad
