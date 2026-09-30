# syntax=docker/dockerfile:1.7
#
# Build (context = docker-images/php):
#   docker build --build-arg PHP_VERSION=8.5 -t yourhub/php:8.5 .
#
# Arguments:
#   PHP_VERSION       version directory and image version (default: 8.5)
#   PHP_BASE_TAG      official PHP base tag (default: ${PHP_VERSION}-fpm-alpine)
#   COMPOSER_VERSION  Composer builder-stage tag (default: 2.8)
#   TZ                container timezone (default: Asia/Shanghai)
#   ALPINE_MIRROR     Alpine apk mirror host, e.g. mirrors.ustc.edu.cn

ARG PHP_VERSION=8.5
ARG PHP_BASE_TAG=${PHP_VERSION}-fpm-alpine
# Capture the requested directory before FROM: official PHP images define ENV PHP_VERSION.
ARG PHP_TARGET_VERSION=${PHP_VERSION}
ARG COMPOSER_VERSION=2.8
FROM composer:${COMPOSER_VERSION} AS composer
FROM php:${PHP_BASE_TAG}

ARG PHP_TARGET_VERSION
ARG TZ=Asia/Shanghai
ARG ALPINE_MIRROR=

LABEL org.opencontainers.image.title="DNMP PHP-FPM ${PHP_TARGET_VERSION}" \
      org.opencontainers.image.description="PHP-FPM ${PHP_TARGET_VERSION} runtime with common extensions and optimized defaults" \
      org.opencontainers.image.version="${PHP_TARGET_VERSION}" \
      org.opencontainers.image.authors="Nick <facelook@163.com>" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/oauthq/dockerfile"

# Reject a base tag from another PHP version before installing dependencies.
RUN php -r 'if (PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION !== $argv[1]) { fwrite(STDERR, sprintf("PHP_BASE_TAG must match PHP_VERSION: requested %s, base image provides %s\n", $argv[1], PHP_VERSION)); exit(1); }' "${PHP_TARGET_VERSION}"

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

# Version-specific extensions and local packages; dependency management stays shared.
ARG PHP_EXTENSIONS
COPY install-php-extensions /usr/local/bin/install-php-extensions
COPY ${PHP_TARGET_VERSION}/extensions/ /tmp/extensions/
RUN chmod 755 /usr/local/bin/install-php-extensions \
    && PHP_EXTENSIONS="${PHP_EXTENSIONS:-}" sh /tmp/extensions/install.sh \
    && rm -rf /tmp/extensions

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

COPY ${PHP_TARGET_VERSION}/conf.d/ /usr/local/etc/php/conf.d/
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
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=3 CMD ["php-fpm-healthcheck"]
STOPSIGNAL SIGQUIT
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]
