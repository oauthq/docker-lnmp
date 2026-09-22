#!/bin/sh
set -eu

# Generic HTTP healthcheck: nginx is healthy when it answers with any
# HTTP status code (2xx/3xx/4xx/5xx). Does not depend on a specific
# location, so it keeps working if the user overrides the site config.
# Configurable via environment:
#   NGINX_HEALTHCHECK_URL   URL to probe (default: http://127.0.0.1:80/)

NGINX_HEALTHCHECK_URL="${NGINX_HEALTHCHECK_URL:-http://127.0.0.1:80/}"

command -v wget >/dev/null 2>&1 || {
    echo "wget not found, ensure busybox is installed" >&2
    exit 4
}

out=$(wget -q -S -O /dev/null -T 3 "${NGINX_HEALTHCHECK_URL}" 2>&1) || true

case "${out}" in
    *"HTTP/"*) exit 0 ;;
    *) exit 1 ;;
esac