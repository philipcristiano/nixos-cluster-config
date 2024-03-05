set -ex

SERVICE_ID=handbrake
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

vault policy write service-handbrake policy.vault

# nomad volume create handbrake.volume
nomad run -var-file=../../nomad_job.vars -var="image_id=${IMAGE_ID}" handbrake.nomad
