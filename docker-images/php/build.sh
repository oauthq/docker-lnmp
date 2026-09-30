#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ -f .env ]; then
    . ./.env
fi

: "${IMAGE_NAMESPACE:=yourhub}"
: "${PHP_VERSIONS:=8.5}"
: "${COMPOSER_VERSION:=2.8}"
: "${PHP_EXTENSIONS:=}"
: "${TZ:=Asia/Shanghai}"
: "${ALPINE_MIRROR:=}"
: "${PLATFORMS:=}"

command="${1:-build}"

case "${command}" in
    build|push)
        ;;
    *)
        echo "Usage: $0 [build|push]" >&2
        exit 1
        ;;
esac

for version in ${PHP_VERSIONS}; do
    if [ ! -f "${version}/extensions/install.sh" ] || [ ! -d "${version}/conf.d" ]; then
        echo "Missing PHP configuration or extension installer for version: ${version}" >&2
        exit 1
    fi
    case "${version}" in
        7.4) base_tag="7.4.33-fpm-alpine" ;;
        *) base_tag="${version}-fpm-alpine" ;;
    esac
    tag="${IMAGE_NAMESPACE}/php:${version}"
    echo "==> ${command}: ${tag}"

    set -- \
        --build-arg "PHP_VERSION=${version}" \
        --build-arg "PHP_BASE_TAG=${base_tag}" \
        --build-arg "TZ=${TZ}" \
        --build-arg "COMPOSER_VERSION=${COMPOSER_VERSION}" \
        --build-arg "PHP_EXTENSIONS=${PHP_EXTENSIONS}"
    if [ -n "${ALPINE_MIRROR}" ]; then
        set -- "$@" --build-arg "ALPINE_MIRROR=${ALPINE_MIRROR}"
    fi

    if [ -n "${PLATFORMS}" ]; then
        case "${command}" in
            build)
                case "${PLATFORMS}" in
                    *,*)
                        echo "Cannot load a multi-platform image locally; use '$0 push' instead." >&2
                        exit 1
                        ;;
                esac
                docker buildx build --load --platform "${PLATFORMS}" -f Dockerfile "$@" -t "${tag}" .
                ;;
            push)
                docker buildx build --push --platform "${PLATFORMS}" -f Dockerfile "$@" -t "${tag}" .
                ;;
        esac
    elif [ "${command}" = "build" ]; then
        docker build -f Dockerfile "$@" -t "${tag}" .
    else
        docker push "${tag}"
    fi
done
