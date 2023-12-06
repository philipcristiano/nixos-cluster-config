set -ex

vault policy write service-hello-idc policy.vault

nomad run -var-file=../../nomad_job.vars hello_idc.nomad
