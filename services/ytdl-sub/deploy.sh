set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-06-25
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:f61c27406587ad362c39397672b0397bbb1c402853f110c34b823ab530c23209"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
