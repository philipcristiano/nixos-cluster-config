set -ex

vault policy write service-mktxp policy.vault

nomad run -var-file=../../nomad_job.vars mktxp-router.nomad
