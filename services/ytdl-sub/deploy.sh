set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

nomad run -var-file=../../nomad_job.vars -var-file=./service.vars ytdl-sub.nomad
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars ytdl-sub-once.nomad
