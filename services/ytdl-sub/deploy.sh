set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-09-13
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:d96d4c510e080f27da78846dc5495a79a1c0e3d9e74c8d0c5429d41c379b227e"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
