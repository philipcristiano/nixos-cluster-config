set -ex

SERVICES=(
  "docker-prefetch-image"
  "minio-system"
  "docker-registry"
  "traefik"
  "regctl"
  "docker-registry-ui"
  "csi-nfs"
  "kanidm"
  "telegraf"
  "grafana"
  "ntfy"
  "grafana-to-ntfy"
  "loki"
  "rmqtt"
  "frigate"
  "miniflux"
  "homeassistant"
  "hello_idc"
  "timeline"
  "hvac-iot"
  "tika"
  "gotenberg"
  "jellyfin"
  "calibre-web"
  "rotki"
  "simplefin-rotki"
  "zwavejs2mqtt"
  "regctl"
  "actual"
  "handbrake"
  "timeline"
  "ytdl-sub"
  "llm-web"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
