set -ex

vault policy write service-docker-prefetch-image policy.vault

### Define which services need prefetching
PREFETCH_DOCKER_HUB=(
    "minio-system"
)

### Dispatch the copy job to the local repository and set into consul to pull the image
for D in ${PREFETCH_DOCKER_HUB[@]}; do
  IMAGE_ID=$(awk '/FROM/ {print $2}' "../${D}/Dockerfile")
  nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${PREFETCH_DOCKER_HUB}" regctl-img-copy
  consul kv put "docker-prefetch/${D}" "${IMAGE_ID}"
done

### Deploy the prefetch job

SERVICE_ID=docker-prefetch-image
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
nomad run -var-file=../../nomad_job.vars -var "image_id=${IMAGE_ID}" "${SERVICE_ID}.nomad"
