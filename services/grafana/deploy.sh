set -ex

vault policy write service-grafana policy.vault

#nomad volume create grafana.volume
nomad run -var-file=../../nomad_job.vars grafana.nomad
nomad run -var-file=../../nomad_job.vars grafana-matrix-forwarder.nomad
nomad run -var-file=../../nomad_job.vars grafana-image-renderer.nomad
