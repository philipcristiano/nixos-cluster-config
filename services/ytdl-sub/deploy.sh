set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-09-20
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:bad7327bb54553400e66abda4fa916aa45e8a2241555cb9aeeff9ceccea7d2d8"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
