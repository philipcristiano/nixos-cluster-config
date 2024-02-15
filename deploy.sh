set -ex

SERVICES=(
  "neon"
  "docker-registry"
  "docker-registry-ui"
  "docker-prefetch-image"
  "traefik"
  "bitcoind"
  "electrs"
  "frigate"
  "homeassistant"
  "hello_idc"
  "kanidm"
  "postmoogle"
  "paperless-ngx"
  "rotki"
  "zwavejs2mqtt"
  "synapse"
  "regctl"
  "lightning-network-daemon"
  "ytdl-sub"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
