set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-09-17
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:dcd7aa06a7d1bf75acae0ddda2ec329285b2d6f6b4bd77bb2e9188f5c83810b4"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
