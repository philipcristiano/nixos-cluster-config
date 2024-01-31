set -ex

SERVICES=(
  "neon"
  "docker-registry"
  "docker-registry-ui"
  "homeassistant"
  "hello_idc"
  "kanidm"
  "paperless-ngx"
  "zwavejs2mqtt"
)

for SERVICE in ${SERVICES[@]}; do
  pushd "services/${SERVICE}"
  bash deploy.sh
  popd
done
