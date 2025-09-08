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
  "rmqtt"
  "frigate"
  "homeassistant"
  "timeline"
  "hvac-iot"
  "tika"
  "gotenberg"
  "jellyfin"
  "calibre-web"
  "rotki"
  "simplefin-rotki"
  "regctl"
  "actual"
  "handbrake"
  "ytdl-sub"
  "llm-web"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
