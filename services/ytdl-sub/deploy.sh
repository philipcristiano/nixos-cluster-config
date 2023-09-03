set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-07-18
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:45530f25cfa46aa60e58913428f287236167b4ad32ccc02c65779d82c95cf552"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
