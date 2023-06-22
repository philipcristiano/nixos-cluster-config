set -ex

vault policy write service-ytdl-sub policy.vault

# nomad volume create yt_tvshows.volume
# nomad volume create ytdl-sub.volume
nomad run ytdl-sub.nomad
