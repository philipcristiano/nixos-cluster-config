set -ex

vault policy write service-nostr-rs-relay policy.vault
vault write pki_int/roles/nostr-rs-relay \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="nostr-relay.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

pushd ../neon-compute
bash deploy.sh nostr-rs-relay
popd

SERVICE_ID=nostr-rs-relay
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" nostr-rs-relay.nomad
