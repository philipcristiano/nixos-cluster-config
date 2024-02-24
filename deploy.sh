set -ex

SERVICES=(
  "neon"
  "docker-registry"
  "docker-registry-ui"
  "docker-prefetch-image"
  "minio-system"
  "traefik"
  "telefraf"
  "bitcoind"
  "electrs"
  "lightning-network-daemon"
  "frigate"
  "miniflux"
  "homeassistant"
  "hello_idc"
  "hvac-iot"
  "kanidm"
  "postmoogle"
  "paperless-ngx"
  "rotki"
  "zwavejs2mqtt"
  "synapse"
  "regctl"
  "actual"
  "nostress"
  "ytdl-sub"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
