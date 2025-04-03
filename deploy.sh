set -ex

SERVICES=(
  "docker-prefetch-image"
  "minio-system"
  "docker-registry"
  "traefik"
  "regctl"
  "docker-registry-ui"
  "csi-nfs"
  "telegraf"
  "grafana"
  "ntfy"
  "grafana-to-ntfy"
  "loki"
  "mimir"
  "bitcoind"
  "electrs"
  "rmqtt"
  # "lightning-network-daemon"
  "frigate"
  "kanidm"
  "miniflux"
  "homeassistant"
  "hello_idc"
  "forgejo"
  "w2z"
  "et"
  "timeline"
  "hvac-iot"
  "postmoogle"
  "tika"
  "gotenberg"
  "jellyfin"
  "calibre-web"
  "llm-web"
  "rotki"
  "simplefin-rotki"
  "zwavejs2mqtt"
  "synapse"
  "postmoogle"
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
