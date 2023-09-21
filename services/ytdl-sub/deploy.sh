set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-09-21
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:48b41488d042cb696166e3b4a1f126ec72bb0566a59093a8c09e91a3b9a59141"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
