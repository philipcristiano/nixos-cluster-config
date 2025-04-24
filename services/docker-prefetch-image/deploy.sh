set -ex

vault policy write service-docker-prefetch-image policy.vault

### Define which services need prefetching
PREFETCH_DOCKER_HUB=(
    "minio-system"
    "docker-registry"
    "traefik"
    "kanidm"
    "telegraf"
)
### Define which services need prefetching
PREFETCH_DOCKER_REPO=(
    "regctl"
)

### Dispatch the copy job to the local repository and set into consul to pull the image
for D in ${PREFETCH_DOCKER_HUB[@]}; do
  IMAGE_ID=$(awk '/FROM/ {print $2}' "../${D}/Dockerfile")
  # nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${D}" regctl-img-copy
  consul kv put "docker-prefetch/${D}" "${IMAGE_ID}"
done

# TODO: This requires getting the prefetch config setup correctly with a consul template
### Dispatch the copy job to the local repository and set into consul to pull the image
for D in ${PREFETCH_DOCKER_REPO[@]}; do
  IMAGE_ID=$(awk '/FROM ./ {sub(/.[^\/]*\//, "", $2 ); print $2}' "../${D}/Dockerfile")
  SOURCE_REGISTRY="$(awk '/FROM ./ {sub(/\/.*/, "", $2 ); print $2}' "../${D}/Dockerfile")/"
  # nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${D}" regctl-img-copy
  consul kv put "docker-prefetch-full/${D}/image" "\"docker-registry.home.cristiano.cloud/${IMAGE_ID}\""
  consul kv put "docker-prefetch-full/${D}/alternative_images" "[\"${SOURCE_REGISTRY}${IMAGE_ID}"\"]
done

### Deploy the prefetch job

SERVICE_ID=docker-prefetch-image
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" "${SERVICE_ID}.nomad"
