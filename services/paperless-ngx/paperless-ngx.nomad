variable "image_id" {
  type        = string
  description = "The docker image used for task."
  default     = "paperlessngx/paperless-ngx:1.15.1"
}

job "paperless-ngx" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {

    restart {
      attempts = 2
      interval = "1m"
      delay    = "10s"
      mode     = "delay"
    }

    service {
      name = "paperless-ngx"
      port = "http"

      tags = [
        "traefik.enable=true",
	      "traefik.http.routers.paperless-ngx.tls=true",
	      "traefik.http.routers.paperless-ngx.tls.certresolver=home",
      ]

      check {
        name     = "alive"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }


    network {
      port "http" {
  	    to = 8000
      }
    }

    volume "storage" {
      type            = "csi"
      source          = "paperless-ngx"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "app" {
      driver = "docker"

      config {
        image = var.image_id
        ports = ["http"]

        mount = {
          type     = "bind"
          source   = "local/docker_prepare.sh"
          target   = "/sbin/docker-prepare.sh"
          readonly = true
        }
      }

      volume_mount {
        volume      = "storage"
        destination = "/data/paperless"
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      template {
          env = true
          destination = "local/file.env"
          data = <<EOF
PAPERLESS_REDIS="redis://redis-paperless-ngx.{{ key "site/domain"}}:6380"
PAPERLESS_URL="https://paperless-ngx.{{ key "site/domain"}}"
PAPERLESS_TIKA_GOTENBERG_ENDPOINT=https://gotenberg.{{ key "site/domain"}}
PAPERLESS_TIKA_ENDPOINT=https://tika.{{ key "site/domain"}}
EOF
      }

      env {
          PAPERLESS_DATA_DIR = "/data/paperless/data"
          PAPERLESS_CONSUMPTION_DIR = "/data/paperless/consume"
          PAPERLESS_MEDIA_ROOT = "/data/paperless/data"
          PAPERLESS_CONSUMER_POLLING = 10
          PAPERLESS_DBENGINE = "sqlite"
          PAPERLESS_TIKA_ENABLED = 1
          USERMAP_UID = 0
          USERMAP_GID = 0
      }
      template {
        destination = "local/docker_prepare.sh"
        perms = "655"
        data = <<EOF
#!/usr/bin/env bash

set -e

wait_for_postgres() {
	local attempt_num=1
	local -r max_attempts=5

	echo "Waiting for PostgreSQL to start..."

	local -r host="$\{PAPERLESS_DBHOST:-localhost}"
	local -r port="$\{PAPERLESS_DBPORT:-5432}"

	# Disable warning, host and port can't have spaces
	# shellcheck disable=SC2086
	while [ ! "$(pg_isready -h ${host} -p ${port})" ]; do

		if [ $attempt_num -eq $max_attempts ]; then
			echo "Unable to connect to database."
			exit 1
		else
			echo "Attempt $attempt_num failed! Trying again in 5 seconds..."
		fi

		attempt_num=$(("$attempt_num" + 1))
		sleep 5
	done
}

wait_for_mariadb() {
	echo "Waiting for MariaDB to start..."

	local -r host="$\{PAPERLESS_DBHOST:=localhost}"
	local -r port="$\{PAPERLESS_DBPORT:=3306}"

	local attempt_num=1
	local -r max_attempts=5

	# Disable warning, host and port can't have spaces
	# shellcheck disable=SC2086
	while ! true > /dev/tcp/$host/$port; do

		if [ $attempt_num -eq $max_attempts ]; then
			echo "Unable to connect to database."
			exit 1
		else
			echo "Attempt $attempt_num failed! Trying again in 5 seconds..."

		fi

		attempt_num=$(("$attempt_num" + 1))
		sleep 5
	done
}

wait_for_redis() {
	# We use a Python script to send the Redis ping
	# instead of installing redis-tools just for 1 thing
	if ! python3 /sbin/wait-for-redis.py; then
		exit 1
	fi
}

migrations() {
	(
		echo "Apply database migrations..."
		python3 manage.py migrate --skip-checks --no-input
	)
}

django_checks() {
	# Explicitly run the Django system checks
	echo "Running Django checks"
	python3 manage.py check
}

search_index() {

	local -r index_version=2
	local -r index_version_file=${DATA_DIR}/.index_version

	if [[ (! -f "${index_version_file}") || $(<"${index_version_file}") != "$index_version" ]]; then
		echo "Search index out of date. Updating..."
		python3 manage.py document_index reindex --no-progress-bar
		echo ${index_version} | tee "${index_version_file}" >/dev/null
	fi
}

superuser() {
	if [[ -n "${PAPERLESS_ADMIN_USER}" ]]; then
		python3 manage.py manage_superuser
	fi
}

do_work() {
	if [[ "${PAPERLESS_DBENGINE}" == "mariadb" ]]; then
		wait_for_mariadb
	elif [[ -n "${PAPERLESS_DBHOST}" ]]; then
		wait_for_postgres
	fi

	wait_for_redis

	migrations

	django_checks

	search_index

	superuser

}

do_work

EOF
    }

    }
  }
}