set -ex

vault policy write service-docker-prefetch-image policy.vault

nomad run -var-file=../../nomad_job.vars docker-prefetch-image.nomad

PREFETCH_DOCKER_HUB=(
    "minio-system"
)

for D in ${PREFETCH_DOCKER_HUB[@]}; do
  IMAGE_ID=$(awk '/FROM/ {print $2}' "../${D}/Dockerfile")
  nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
  consul kv put "docker-prefetch/${D}" "${IMAGE_ID}"
done
