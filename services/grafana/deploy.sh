set -ex

vault policy write service-grafana policy.vault

#nomad volume create grafana.volume
nomad run grafana.nomad
nomad run grafana-matrix-forwarder.nomad
nomad run grafana-image-renderer.nomad
