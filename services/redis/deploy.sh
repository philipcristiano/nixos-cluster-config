set -ex

SERVICE_ID=redis
IMAGE_ID=$(awk '/FROM/ {print $2}' Dockerfile)

if [ "$1" = "" ]; then
    echo "Name needs to be specified ./deploy.sh NAME"
    exit 1
fi

cat << EOF > policy.vault

path "kv/data/$1-redis" {
  capabilities = ["read"]
}
EOF

vault policy write service-$1-redis policy.vault

sed "s/JOB_NAME/$1/" redis.nomad > redis-deploy.nomad

nomad run -var=name="${1}" -var="image_id=${IMAGE_ID}" -var-file=../../nomad_job.vars redis-deploy.nomad
