variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "ghcr.io/jmbannon/ytdl-sub@sha256:ff63d940ad3cb71305d5dfef70acbbdfcea58fbfb1fbfd6cac779040fa2f9d3e" # ubuntu-latest as of 2023-06-20
}

job "ytdl-sub" {
  datacenters = ["dc1"]
  type        = "batch"

  periodic {
    cron             = "0 22 * * * *"
    prohibit_overlap = true
  }

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "ytdl-sub"
    }

    volume "storage" {
      type            = "csi"
      source          = "ytdl-sub"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "yt_tvshows" {
      type            = "csi"
      source          = "yt_tvshows"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "prep-disk" {
      driver = "docker"
      volume_mount {
        volume      = "storage"
        destination = "/storage"
        read_only   = false
      }

      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "mkdir -p /storage && chown -R 1000:1000 /storage && chmod 775 /storage"]
      }
      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "app" {
      driver = "docker"

      config {
        # entrypoint = ["sleep", "10000"]
        image = var.image_id

        command = "ytdl-sub"

        args = [
          "-c", "/local/config.yaml",
          "sub",
          "/local/subscriptions.yaml"
        ]

      }
      env {
        PUID = 1000
        PGID = 1000
      }
      template {
          destination = "local/subscriptions.yaml"
          data = <<EOF


{{ range $key, $pairs := safeTree "youtube_subscriptions" | byKey }}

{{ $key }}:
  preset:
    - "tv_show"
  overrides:
{{ range $pair := $pairs }}
    {{ .Key }}: "{{ .Value }}"{{ end }}{{ end }}

EOF
      }
      template {
          destination = "local/config.yaml"
          data = <<EOF
# This config uses prebuilt presets included with ytdl-sub to download and format
# channels from YouTube or other sites supported by yt-dlp into a TV show for
# your favorite player. The directory format will look something like
#
#   /tv_shows
#       /Season 2021
#           s2021.e0317 - Pattys Day Video-thumb.jpg
#           s2021.e0317 - Pattys Day Video.mp4
#           s2021.e0317 - Pattys Day Video.nfo
#       /Season 2022
#           s2022.e1225 - Merry Christmas-thumb.jpg
#           s2022.e1225 - Merry Christmas.mp4
#           s2022.e1225 - Merry Christmas.nfo
#       poster.jpg
#       fanart.jpg
#       tvshow.nfo
#
# The idea is to use dates as numerics to represent season and episode numbers.
configuration:
  working_directory: '/config/wd'

presets:

  # Your main TV show preset - all your tv show subscriptions will use this.
  tv_show:
    preset:
      # Choose one of the following player types:
      # - "kodi_tv_show_by_date"
      # - "jellyfin_tv_show_by_date"
      # - "plex_tv_show_by_date"

      - "jellyfin_tv_show_by_date"  # replace with desired player type

      # Choose one of the following season/episode formats:
      # - "season_by_year__episode_by_month_day"
      # - "season_by_year_month__episode_by_day"
      # - "season_by_year__episode_by_month_day_reversed"
      # - "season_by_year__episode_by_download_index"

      - "season_by_year__episode_by_month_day"  # replace with desired season/episode format

      # Include any of the presets listed below in your 'main preset' if you want
      # it applied to every TV show. Or, use them on the individual subscriptions.
      # - "only_recent_videos"
      # - "add_subtitles"
      # - "sponsorblock"
      # - "include_info_json"

    # To download age-restricted videos, you will need to uncomment and set your cookie
    # file here as a ytdl parameter. For more info, see
    # https://ytdl-sub.readthedocs.io/en/latest/faq.html#download-age-restricted-youtube-videos
    #
    ytdl_options:
    #   cookiefile: "/config/cookie_file.txt"  # replace with actual cookie file path
      maintain_download_archive: true

    overrides:
      tv_show_directory: "/tv_shows"  # replace with path to tv show directory
      # Fields in the prebuilt preset that can be changed:
      #
      # episode_title: "{upload_date_standardized} - {title}"
      # episode_plot: "{webpage_url}"  # source variable for the video description is {description}


EOF
      }

      volume_mount {
        volume      = "storage"
        destination = "/config"
      }

      volume_mount {
        volume      = "yt_tvshows"
        destination = "/tv_shows"
      }

      resources {
        cpu    = 125
        memory = 1024
        memory_max = 4096
      }

    }
  }
}
