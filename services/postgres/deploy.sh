set -ex


if [ "$1" = "" ]; then
    echo "Name needs to be specified ./deploy.sh NAME"
    exit 1
fi

cat << EOF > policy.vault

path "kv/data/$1-postgres" {
  capabilities = ["read"]
}
path "kv/data/service-postgres-backup" {
  capabilities = ["read"]
}
EOF


SERVICE_ID=postgres
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)
BACKUPS3_IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile.backup-s3)

# TODO uncomment after testing the rest of this
nomad job dispatch -meta image="${IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy
nomad job dispatch -meta image="${BACKUPS3_IMAGE_ID}" -id-prefix-template="${SERVICE_ID}" regctl-img-copy

vault policy write service-$1-postgres policy.vault

sed "s/JOB_NAME/$1/" postgres.nomad > postgres-deploy.nomad
sed "s/JOB_NAME/$1/" pgbackrest.conf.tmpl.src > pgbackrest.conf.tmpl
sed "s/JOB_NAME/$1/" backup_s3.env.tmpl.src > backup_s3.env.tmpl
sed "s/JOB_NAME/$1/" postgres-backup.nomad > postgres-backup-deploy.nomad

nomad run -var=name="${1}" -var-file=../../nomad_job.vars -var="image_id=${IMAGE_ID}" -var="backups3_image_id=${BACKUPS3_IMAGE_ID}" postgres-deploy.nomad
 nomad run -var=name="${1}" -var-file=../../nomad_job.vars -var="image_id=${BACKUPS3_IMAGE_ID}" postgres-backup-deploy.nomad
