set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-07-18
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:a352bc37a600e5ebec5fe0c4393d4546d42b434c749105de23f6de81f941d670"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
