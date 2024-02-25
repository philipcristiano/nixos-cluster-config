set -ex

SERVICE_ID=neon
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

vault policy write service-neon policy.vault

nomad run -var-file=../../nomad_job.vars -var="image_id=${IMAGE_ID}" neon.nomad
