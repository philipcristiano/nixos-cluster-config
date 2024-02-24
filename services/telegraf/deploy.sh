set -ex

SERVICE_ID=telegraf
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

vault policy write service-telegraf-prometheus policy.vault

nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" telegraf-system.nomad
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" telegraf-influxdb-input.nomad
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" telegraf-prometheus.nomad
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" telegraf-dc.nomad
