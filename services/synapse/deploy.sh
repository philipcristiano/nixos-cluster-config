set -ex

vault policy write service-synapse policy.vault
vault write pki_int/roles/synapse \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="synapse.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

SERVICE_ID=synapse
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
ADMIN_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.admin)


pushd ../neon-compute
bash deploy.sh synapse
popd

# nomad volume create zwavejs2mqtt.volume
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${ADMIN_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
# nomad volume create paperless-ngx.volume
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" synapse.nomad
nomad run -var-file=../../nomad_job.vars -var "image_id=${ADMIN_IMAGE_ID}" synapse-admin.nomad
