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
: "${CONTAINER_PACKAGE_URL:=}"
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
    tag="${IMAGE_NAMESPACE}/php:${version}"
    echo "==> ${command}: ${tag}"

    set -- \
        --build-arg "TZ=${TZ}" \
        --build-arg "COMPOSER_VERSION=${COMPOSER_VERSION}" \
        --build-arg "PHP_EXTENSIONS=${PHP_EXTENSIONS}"
    if [ -n "${CONTAINER_PACKAGE_URL}" ]; then
        set -- "$@" --build-arg "CONTAINER_PACKAGE_URL=${CONTAINER_PACKAGE_URL}"
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
                docker buildx build --load --platform "${PLATFORMS}" -f "${version}/Dockerfile" "$@" -t "${tag}" .
                ;;
            push)
                docker buildx build --push --platform "${PLATFORMS}" -f "${version}/Dockerfile" "$@" -t "${tag}" .
                ;;
        esac
    elif [ "${command}" = "build" ]; then
        docker build -f "${version}/Dockerfile" "$@" -t "${tag}" .
    else
        docker push "${tag}"
    fi
done
