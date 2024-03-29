set -ex

SERVICES=(
  "docker-prefetch-image"
  "minio-system"
  "docker-registry"
  "regctl"
  "docker-registry-ui"
  "traefik"
  "csi-nfs"
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
  "w2z"
  "hvac-iot"
  "kanidm"
  "postmoogle"
  "tika"
  "gotenberg"
  "jellyfin"
  "llm"
  "rotki"
  "zwavejs2mqtt"
  "synapse"
  "regctl"
  "actual"
  "handbrake"
  "nostress"
  "nostr-rs-relay"
  "timeline"
  "ytdl-sub"
  "paperless-ngx"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
