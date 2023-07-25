set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

## ubuntu-latest as of 2023-07-18
export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@sha256:169a20b0f61ff27270c620af47b9818a16590910b01d905ee396f13b8ef4faa7"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
