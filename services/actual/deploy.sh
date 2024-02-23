set -ex

SERVICE_ID=actual
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

# nomad volume create actual.volume
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" actual.nomad
