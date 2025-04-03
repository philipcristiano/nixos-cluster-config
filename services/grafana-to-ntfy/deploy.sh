set -ex

SERVICE_ID=grafana-to-ntfy
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

vault policy write service-${SERVICE_ID} policy.vault

nomad run -var-file=../../nomad_job.vars -var="image_id=${IMAGE_ID}" ${SERVICE_ID}.nomad
