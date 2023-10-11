set -ex

vault policy write service-handbrake policy.vault

# nomad volume create handbrake.volume
nomad run -var-file=../../nomad_job.vars handbrake.nomad
