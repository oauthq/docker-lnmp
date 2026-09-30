# syntax=docker/dockerfile:1.7
#
# Build (context = docker-images/php):
#   docker build -f 8.3/Dockerfile -t yourhub/php:8.3 .
#
# Arguments:
#   TZ                     container timezone (default: Asia/Shanghai)
#   ALPINE_MIRROR  Alpine apk mirror host, e.g. mirrors.ustc.edu.cn

ARG COMPOSER_VERSION=2.8
FROM composer:${COMPOSER_VERSION} AS composer
FROM php:8.3-fpm-alpine

ARG TZ=Asia/Shanghai
ARG ALPINE_MIRROR=

LABEL org.opencontainers.image.title="DNMP PHP-FPM 8.3" \
      org.opencontainers.image.description="PHP-FPM 8.3 runtime with common extensions and optimized defaults" \
      org.opencontainers.image.version="8.3" \
      org.opencontainers.image.authors="Nick <facelook@163.com>" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/oauthq/dockerfile"

ENV APP_HOME=/var/www/html \
    TZ=${TZ} \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer \
    COMPOSER_MAX_PARALLEL_HTTP=24 \
    LD_PRELOAD=/usr/lib/preloadable_libiconv.so

# apk mirror switch (changes with ALPINE_MIRROR)
RUN set -eux; \
    if [ -n "${ALPINE_MIRROR:-}" ]; then \
        sed -i "s#dl-cdn.alpinelinux.org#${ALPINE_MIRROR:-}#g" /etc/apk/repositories; \
    fi

# System packages: the most expensive, most stable layer
RUN set -eux; \
    apk add --no-cache ca-certificates curl fcgi gnu-libiconv shadow tzdata

# Timezone (changes with TZ)
RUN set -eux; \
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime; \
    echo "${TZ}" > /etc/timezone

# Host-matching uid/gid
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

# PHP extensions via docker-php-extension-installer:
# resolves build/runtime deps, version compatibility and cleanup automatically
ARG PHP_EXTENSIONS
COPY install-php-extensions /usr/local/bin/install-php-extensions
COPY 8.3/extensions/ /tmp/extensions/
RUN chmod 755 /usr/local/bin/install-php-extensions \
    && PHP_EXTENSIONS="${PHP_EXTENSIONS:-}" sh /tmp/extensions/install.sh \
    && rm -rf /tmp/extensions

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

COPY 8.3/conf.d/ /usr/local/etc/php/conf.d/
COPY php-fpm.conf /usr/local/etc/php-fpm.d/zz-app.conf
COPY healthcheck.sh /usr/local/bin/php-fpm-healthcheck

WORKDIR ${APP_HOME}

RUN set -eux; \
    chown -R www-data:www-data "${APP_HOME}"; \
    chmod 755 "${APP_HOME}"; \
    mkdir -p "${COMPOSER_HOME}"; \
    chown -R www-data:www-data "${COMPOSER_HOME}"; \
    chmod 755 /usr/local/bin/php-fpm-healthcheck

USER www-data
EXPOSE 9000
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --start-interval=3s --retries=3 CMD ["php-fpm-healthcheck"]
STOPSIGNAL SIGQUIT
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]
