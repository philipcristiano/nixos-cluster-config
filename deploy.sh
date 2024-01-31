set -ex

SERVICES=(
  "neon"
  "docker-registry"
  "docker-registry-ui"
  "frigate"
  "homeassistant"
  "hello_idc"
  "kanidm"
  "paperless-ngx"
  "rotki"
  "zwavejs2mqtt"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
