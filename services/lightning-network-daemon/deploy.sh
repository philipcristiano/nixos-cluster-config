set -ex


set -ex

SERVICE_ID=lightning-network-daemon
LND_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.lnd)
TERMINAL_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.terminal)
TOR_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.tor)
MON_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.mon)

# nomad volume create lightning-network-daemon.volume

nomad job dispatch -meta image="${LND_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${TERMINAL_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${TOR_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${MON_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

vault policy write service-lightning-network-daemon policy.vault
vault policy write service-lightning-terminal policy.vault

nomad run -var-file=../../nomad_job.vars -var "lnd_image_id=${LND_IMAGE_ID}" -var "terminal_image_id=${TERMINAL_IMAGE_ID}" -var "tor_image_id=${TOR_IMAGE_ID}" -var "lndmon_image_id=${MON_IMAGE_ID}" "${SERVICE_ID}.nomad"
