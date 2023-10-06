set -ex


# nomad volume create zwavejs2mqtt.volume

nomad run -var-file=../../nomad_job.vars zwavejs2mqtt.nomad
