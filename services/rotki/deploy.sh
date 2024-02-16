set -ex

vault policy write service-rotki policy.vault

SERVICE_ID=rotki
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

# nomad volume create rokti.volume
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" rotki.nomad
