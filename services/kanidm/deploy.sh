set -ex

SERVICE_ID=kanidm
SERVER_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
RADIUS_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.radius)
TOOLS_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.tools)

vault policy write "service-${SERVICE_ID}" policy.vault

nomad job dispatch -meta image="${SERVER_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${RADIUS_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${TOOLS_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy


vault policy write service-kanidm policy.vault
vault write pki_int/roles/kanidm \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="kanidm.home.cristiano.cloud,ldap.home.cristiano.cloud,radius.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create kanidm.volume
nomad run -var-file=../../nomad_job.vars -var "image_id=${SERVER_IMAGE_ID}" "${SERVICE_ID}.nomad"
nomad run -var-file=../../nomad_job.vars -var "image_id=${RADIUS_IMAGE_ID}" "${SERVICE_ID}-radius.nomad"
nomad run -var-file=../../nomad_job.vars -var "image_id=${TOOLS_IMAGE_ID}" "${SERVICE_ID}-tools.nomad"
