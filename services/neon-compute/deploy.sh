set -ex


# nomad volume create minio.volume
if [ "$1" = "" ]; then
    echo "Name needs to be specified ./deploy.sh NAME"
    exit 1
fi

cat << EOF > policy.vault

path "kv/data/$1-postgres" {
  capabilities = ["read"]
}
EOF

vault policy write service-$1-postgres policy.vault

sed "s/JOB_NAME/$1/" neon-compute.nomad > neon-compute-deploy.nomad
sed "s/JOB_NAME/$1/" neon-compute-postgres-backup.nomad > neon-compute-postgres-backup-deploy.nomad

nomad run -var=name="${1}" -var-file=../../nomad_job.vars neon-compute-deploy.nomad
nomad run -var=name="${1}" -var-file=../../nomad_job.vars neon-compute-postgres-backup-deploy.nomad
