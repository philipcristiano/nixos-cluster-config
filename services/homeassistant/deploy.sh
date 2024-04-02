set -ex

vault policy write service-homeassistant policy.vault
vault write pki_int/roles/homeassistant \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="homeassistant.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

SERVICE_ID=homeassistant
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
PIPER_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.piper)
WHISPER_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.whisper)
# nomad volume create homeassistant.volume
# nomad volume create homeassistant-whisper.volume
# nomad volume create homeassistant-piper.volume
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${PIPER_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${WHISPER_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" homeassistant.nomad
nomad run -var-file=../../nomad_job.vars -var "image_id=${PIPER_IMAGE_ID}" homeassistant-piper.nomad
nomad run -var-file=../../nomad_job.vars -var "image_id=${WHISPER_IMAGE_ID}" homeassistant-whisper.nomad
