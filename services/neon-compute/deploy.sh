set -ex


if [ "$1" = "" ]; then
    echo "Name needs to be specified ./deploy.sh NAME"
    exit 1
fi

cat << EOF > policy.vault

path "kv/data/$1-postgres" {
  capabilities = ["read"]
}
EOF


SERVICE_ID=neon-compute
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
POSTGRES_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.postgres)

nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

vault policy write service-$1-postgres policy.vault

sed "s/JOB_NAME/$1/" neon-compute.nomad > neon-compute-deploy.nomad
sed "s/JOB_NAME/$1/" neon-compute-postgres-backup.nomad > neon-compute-postgres-backup-deploy.nomad

nomad run -var=name="${1}" -var-file=../../nomad_job.vars -var="image_id=${IMAGE_ID}" neon-compute-deploy.nomad
nomad run -var=name="${1}" -var-file=../../nomad_job.vars -var="image_id=${POSTGRES_IMAGE_ID}" neon-compute-postgres-backup-deploy.nomad
