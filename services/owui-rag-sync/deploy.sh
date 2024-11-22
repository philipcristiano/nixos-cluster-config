set -ex

SERVICE_ID=owui-rag-sync
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

vault policy write "service-${SERVICE_ID}" policy.vault


# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume
#
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" owui-rag-sync.nomad
