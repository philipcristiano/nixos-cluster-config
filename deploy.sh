set -ex

SERVICES=(
  "minio-system"
  "docker-registry"
  "docker-registry-ui"
  "docker-prefetch-image"
  "traefik"
  "neon"
  "telegraf"
  "grafana"
  "loki"
  "mimir"
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
  "jellyfin"
  "llm"
  "rotki"
  "zwavejs2mqtt"
  "synapse"
  "regctl"
  "actual"
  "nostress"
  "nostr-rs-relay"
  "ytdl-sub"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
