set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume

export NOMAD_VAR_image_id="ghcr.io/jmbannon/ytdl-sub@ubuntu-2023.09.22.post5"

nomad run ytdl-sub.nomad
nomad run ytdl-sub-once.nomad
