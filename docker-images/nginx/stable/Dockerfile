# syntax=docker/dockerfile:1.7
#
# Build (context = docker-images/nginx):
#   docker build -f stable/Dockerfile -t yourhub/nginx:stable .
#
# Arguments:
#   NGINX_BASE_TAG         base image tag, nginx:${NGINX_BASE_TAG} (default: stable-alpine)
#   TZ                     container timezone (default: Asia/Shanghai)
#   CONTAINER_PACKAGE_URL  Alpine apk mirror host, e.g. mirrors.ustc.edu.cn

ARG NGINX_BASE_TAG=stable-alpine
FROM nginx:${NGINX_BASE_TAG}

ARG TZ=Asia/Shanghai
ARG CONTAINER_PACKAGE_URL=

LABEL org.opencontainers.image.title="oauthq Nginx" \
      org.opencontainers.image.description="Nginx runtime with optimized defaults" \
      org.opencontainers.image.version="stable" \
      org.opencontainers.image.authors="Nick <facelook@163.com>" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/oauthq/dockerfile"

ENV APP_HOME=/var/www/html \
    TZ=${TZ}

# apk mirror switch (changes with CONTAINER_PACKAGE_URL)
RUN set -eux; \
    if [ -n "${CONTAINER_PACKAGE_URL:-}" ]; then \
        sed -i "s#dl-cdn.alpinelinux.org#${CONTAINER_PACKAGE_URL:-}#g" /etc/apk/repositories; \
    fi

# System packages: the most expensive, most stable layer
RUN set -eux; \
    apk add --no-cache shadow tzdata

# Timezone (changes with TZ)
RUN set -eux; \
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime; \
    echo "${TZ}" > /etc/timezone

# Logs to stdout/stderr so `docker logs` works
RUN set -eux; \
    ln -sf /dev/stdout /var/log/nginx/access.log; \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Host-matching uid/gid: align nginx worker with php-fpm www-data (1000);
# master stays root to bind <1024 ports (e.g. 80)
RUN set -eux; \
    groupmod -g 1000 nginx; \
    usermod -u 1000 -g 1000 nginx; \
    mkdir -p "${APP_HOME}"; \
    chown -R nginx:nginx "${APP_HOME}" /var/log/nginx /var/cache/nginx

# Custom main config (worker_processes, gzip, fastcgi timeouts, ...)
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Optional downstream liveness helper; this base image intentionally does not
# declare HEALTHCHECK because downstream HTTP routes and readiness semantics vary.
COPY healthcheck.sh /usr/local/bin/nginx-healthcheck

RUN chmod 755 /usr/local/bin/nginx-healthcheck

WORKDIR ${APP_HOME}

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
