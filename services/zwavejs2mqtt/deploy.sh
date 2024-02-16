set -ex

SERVICE_ID=zwavejs
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

# nomad volume create zwavejs2mqtt.volume
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" zwavejs2mqtt.nomad
