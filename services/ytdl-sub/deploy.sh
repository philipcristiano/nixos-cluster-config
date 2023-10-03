set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

export NOMAD_VAR_image_id="jmbannon/ytdl-sub:ubuntu-2023.10.03"

nomad run -var-file=../../nomad_job.vars ytdl-sub.nomad
nomad run -var-file=../../nomad_job.vars ytdl-sub-once.nomad
