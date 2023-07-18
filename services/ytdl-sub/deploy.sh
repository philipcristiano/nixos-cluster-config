set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-07-18
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:28055138884b0f7149ee4f82b172675a3f2d74cf1c6374cf8a3122183408c4c2 "

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
