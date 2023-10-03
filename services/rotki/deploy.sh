set -ex

vault policy write service-rotki policy.vault

# nomad volume create rokti.volume
nomad run -var-file=../../nomad_job.vars rotki.nomad
