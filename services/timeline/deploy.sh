set -ex

vault policy write service-timeline policy.vault

pushd ../postgres
bash deploy.sh timeline
popd

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars timeline.nomad
