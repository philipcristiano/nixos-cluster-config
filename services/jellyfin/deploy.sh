set -ex

vault policy write service-jellyfin policy.vault

SERVICE_ID=jellyfin
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" jellyfin.nomad
