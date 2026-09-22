#!/bin/sh
set -eu

# FastCGI ping healthcheck for PHP-FPM.
# Requires php-fpm `ping.path` configured (see php-fpm.conf).
# Configurable via environment:
#   FCGI_CONNECT     host:port (default: 127.0.0.1:9000)
#   FCGI_PING_PATH   ping URI (default: /ping)

FCGI_CONNECT="${FCGI_CONNECT:-127.0.0.1:9000}"
FCGI_PING_PATH="${FCGI_PING_PATH:-/ping}"

command -v cgi-fcgi >/dev/null 2>&1 || {
    echo "cgi-fcgi not found, make sure fcgi is installed (apk add --no-cache fcgi)" >&2
    exit 4
}

if ! SCRIPT_NAME="${FCGI_PING_PATH}" \
    SCRIPT_FILENAME="${FCGI_PING_PATH}" \
    REQUEST_METHOD=GET \
    cgi-fcgi -bind -connect "${FCGI_CONNECT}" 2>/dev/null | grep -q 'pong'; then
    exit 1
fi

exit 0