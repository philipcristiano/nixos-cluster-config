variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "asonix/pictrs:0.3.3"
}

variable "count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

job "pictrs" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    count = var.count

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
    }

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "pictrs"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.pictrs.tls=true",
	      "traefik.http.routers.pictrs.tls.certresolver=home",
      ]

      check {
        name     = "tcp"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "pictrs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      port "http" {
  	    to = 8080
      }
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
        args         = ["-c", "mkdir -p /storage/data && chown -R 991:991 /storage && chmod 775 /storage"]
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

      user = "app"

      vault {
        policies = ["service-pictrs"]
      }

      config {
        image = var.image_id
        ports = ["http"]
        # entrypoint = ["sleep", "10000"]
        command = "/usr/local/bin/pict-rs"
        args = [
          "--config-file", "/secrets/pictrs.toml",
          "--path", "/mnt",
        ]

      }

      volume_mount {
        volume      = "storage"
        destination = "/mnt"
      }

      resources {
        cpu    = 50
        memory = 96
        memory_max = 256
      }

      env {
        RUST_BACKTRACE=full
      }

      template {
        destination = "secrets/pictrs.toml"
        data = <<EOF


## Server configuration
[server]
## Optional: pict-rs binding address
# environment variable: PICTRS__SERVER__ADDRESS
# default: 0.0.0.0:8080
address = '0.0.0.0:8080'

## Optional: pict-rs worker id
# environment variable PICTRS__SERVER__WORKER_ID
# default: pict-rs-1
#
# This is used for the internal job queue. It will have more meaning once a shared metadata
# repository (like postgres) can be defined.
worker_id = 'pict-rs-1'

## Optional: shared secret for internal endpoints
# environment variable: PICTRS__SERVER__API_KEY
# default: empty
#
# Not specifying api_key disables internal endpoints
api_key = '{{with secret "kv/data/pictrs"}}{{.Data.data.api_key}}{{end}}'


## Logging configuration
[tracing.logging]
## Optional: log format
# environment variable: PICTRS__TRACING__LOGGING__FORMAT
# default: normal
#
# available options: compact, json, normal, pretty
format = 'json'

## Optional: log targets
# environment variable: PICTRS__TRACING__LOGGING__TARGETS
# default: warn,tracing_actix_web=info,actix_server=info,actix_web=info
#
# Dictates which traces should print to stdout
# Follows the same format as RUST_LOG
targets = 'warn,tracing_actix_web=info,actix_server=info,actix_web=info'


## Console configuration
[tracing.console]
## Optional: console address
# environment variable: PICTRS__TRACING__CONSOLE__ADDRESS
# default: empty
#
# Dictates whether console should be enabled, and what address it should be exposed on.
#
# When set, tokio-console can connect to the pict-rs service
#
# Configure your container to expose the console port
# ```
# # docker-compose.yml
# version: '3.3'
#
# services:
#   pictrs:
#     image: asonix/pictrs:v0.4.0-alpha.1
#     ports:
#       - "127.0.0.1:8080:8080"
#       - "127.0.0.1:6669:6669" # this is the line that exposes console
#     restart: always
#     volumes:
#       - ./volumes/pictrs:/mnt
# ```
#
# Connect from console
# ```
# $ tokio-console http://localhost:6669
# ```
address = '0.0.0.0:6669'

## Optional: console buffer capacity
# environment variable: PICTRS__TRACING__CONSOLE__BUFFER_CAPACITY
# default: 102400
#
# This is the number of _events_ to buffer, not the number of bytes. In reality, the amount of
# RAM used will be significatnly larger (in bytes) than the buffer capacity (in events)
buffer_capacity = 102400


## OpenTelemetry configuration
[tracing.opentelemetry]
## Optional: url for exporting otlp traces
# environment variable: PICTRS__TRACING__OPENTELEMETRY__URL
# default: empty
#
# Not specifying opentelemetry_url means no traces will be exported
# When set, pict-rs will export OpenTelemetry traces to the provided URL. If the URL is
# inaccessible, this can cause performance degredation in pict-rs, so it is best left unset unless
# you have an OpenTelemetry collector
url = 'http://localhost:4317/'

## Optional: name to relate OpenTelemetry traces
# environment variable: PICTRS__TRACING__OPENTELEMETRY__SERVICE_NAME
# default: pict-rs
service_name = 'pict-rs'

## Optional: trace level to export
# environment variable: PICTRS__TRACING__OPENTELEMETRY__TARGETS
# default: info
#
# Follows the same format as RUST_LOG
targets = 'info'


## Configuration for migrating from pict-rs 0.2
[old_db]
## Optional: path to old pict-rs directory
# environment variable: PICTRS__OLD_DB__PATH
# default: /mnt
path = '/mnt'


## Media Processing Configuration
[media]
## Optional: preprocessing steps for uploaded images
# environment variable: PICTRS__MEDIA__PREPROCESS_STEPS
# default: empty
#
# This configuration is the same format as the process endpoint's query arguments
preprocess_steps = 'crop=16x9&resize=1200&blur=0.2'

## Optional: max media width (in pixels)
# environment variable: PICTRS__MEDIA__MAX_WIDTH
# default: 10,000
max_width = 10000

## Optional: max media height (in pixels)
# environment variable: PICTRS__MEDIA__MAX_HEIGHT
# default: 10,000
max_height = 10000

## Optional: max media area (in pixels)
# environment variable: PICTRS__MEDIA__MAX_AREA
# default: 40,000,000
max_area = 40000000

## Optional: max file size (in Megabytes)
# environment variable: PICTRS__MEDIA__MAX_FILE_SIZE
# default: 40
max_file_size = 40

## Optional: max frame count
# environment variable: PICTRS__MEDIA__MAX_FRAME_COUNT
# default: # 900
max_frame_count = 900

## Optional: enable GIF, MP4, and WEBM uploads (without sound)
# environment variable: PICTRS__MEDIA__ENABLE_SILENT_VIDEO
# default: true
#
# Set this to false to serve static images only
enable_silent_video = true

## Optional: enable MP4, and WEBM uploads (with sound) and GIF (without sound)
# environment variable: PICTRS__MEDIA__ENABLE_FULL_VIDEO
# default: false
enable_full_video = false

## Optional: set the default video codec
# environment variable: PICTRS__MEDIA__VIDEO_CODEC
# default: vp9
#
# available options: av1, h264, h265, vp8, vp9
# this setting does nothing if video is not enabled
video_codec = "vp9"

## Optional: set the default audio codec
# environment variable: PICTRS__MEDIA__AUDIO_CODEC
# default: empty
#
# available options: aac, opus, vorbis
# The audio codec is automatically selected based on video codec, but can be overriden
# av1, vp8, and vp9 map to opus
# h264 and h265 map to aac
# vorbis is not default for any codec
# this setting does nothing if full video is not enabled
audio_codec = "aac"

## Optional: set allowed filters for image processing
# environment variable: PICTRS__MEDIA__FILTERS
# default: ['blur', 'crop', 'identity', 'resize', 'thumbnail']
filters = ['blur', 'crop', 'identity', 'resize', 'thumbnail']

## Optional: whether to validate images uploaded through the `import` endpoint
# environment variable: PICTRS__MEDIA__SKIP_VALIDATE_IMPORTS
# default: false
#
# Set this to true if you want to avoid processing imported media
skip_validate_imports = false

## Optional: The duration, in hours, to keep media ingested through the "cache" endpoint
# environment variable: PICTRS__MEDIA__CACHE_DURATION
# default: 168 (1 week)
cache_duration = 168

## Gif configuration
#
# Making any of these bounds 0 will disable gif uploads
[media.gif]
# Optional: Maximum width in pixels for uploaded gifs
# environment variable: PICTRS__MEDIA__GIF__MAX_WIDTH
# default: 128
#
# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_width = 128

# Optional: Maximum height in pixels for uploaded gifs
# environment variable: PICTRS__MEDIA__GIF__MAX_HEIGHT
# default: 128
#
# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_height = 128

# Optional: Maximum area in pixels for uploaded gifs
# environment variable: PICTRS__MEDIA__GIF__MAX_AREA
# default: 16384 (128 * 128)
#
# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_area = 16384

# Optional: Maximum number of frames permitted in uploaded gifs
# environment variable: PICTRS__MEDIA__GIF__MAX_FRAME_COUNT
# default: 100
#
# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_frame_count = 100


## Database configuration
[repo]
## Optional: database backend to use
# environment variable: PICTRS__REPO__TYPE
# default: sled
#
# available options: sled
type = 'sled'

## Optional: path to sled repository
# environment variable: PICTRS__REPO__PATH
# default: /mnt/sled-repo
path = '/mnt/sled-repo'

## Optional: in-memory cache capacity for sled data (in bytes)
# environment variable: PICTRS__REPO__CACHE_CAPACITY
# default: 67,108,864 (1024 * 1024 * 64, or 64MB)
cache_capacity = 67108864


## Media storage configuration
[store]
## Optional: type of media storage to use
# environment variable: PICTRS__STORE__TYPE
# default: filesystem
#
# available options: filesystem, object_storage
type = 'file_store'

## Required: endpoint at which the object storage exists
# environment variable: PICTRS__STORE__ENDPOINT
# default: empty
#
# examples:
# - `http://localhost:9000` # minio
# - `https://s3.dualstack.eu-west-1.amazonaws.com` # s3
endpoint = 'http://minio.{{ key "site/domain" }}:9000'

## Optional: How to format object storage requests
# environment variable: PICTRS__STORE__USE_PATH_STYLE
# default: false
#
# When this is true, objects will be fetched from http{s}://{endpoint}:{port}/{bucket_name}/{object}
# When false, objects will be fetched from http{s}://{bucket_name}.{endpoint}:{port}/{object}
#
# Set to true when using minio
use_path_style = false

## Required: object storage bucket name
# environment variable: PICTRS__STORE__BUCKET_NAME
# default: empty
bucket_name = 'pictrs'

## Required: object storage region
# environment variable: PICTRS__STORE__REGION
# default: empty
#
# When using minio, this can be set to `minio`
region = 'minio'

## Required: object storage access key
# environment variable: PICTRS__STORE__ACCESS_KEY
# default: empty
access_key = "ACCESS_KEY"

## Required: object storage secret key
# environment variable: PICTRS__STORE__SECRET_KEY
# default: empty
secret_key = "SECRET_KEY"

## Optional: object storage session token
# environment variable: PICTRS__STORE__SESSION_TOKEN
# default: empty
session_token = 'SESSION_TOKEN'

## Filesystem media storage example
# ## Media storage configuration
# [store]
# ## Optional: type of media storage to use
# # environment variable: PICTRS__STORE__TYPE
# # default: filesystem
# #
# # available options: filesystem, object_storage
# type = 'filesystem'
#
# ## Optional: path to uploaded media
# # environment variable: PICTRS__STORE__PATH
# # default: /mnt/files
# path = '/mnt/files'

EOF

      }

    }
  }
}



