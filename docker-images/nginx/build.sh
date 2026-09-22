#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ -f .env ]; then
    . ./.env
fi

: "${IMAGE_NAMESPACE:=yourhub}"
: "${NGINX_VERSIONS:=stable}"
: "${NGINX_BASE_TAG:=stable-alpine}"
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

for version in ${NGINX_VERSIONS}; do
    tag="${IMAGE_NAMESPACE}/nginx:${version}"
    echo "==> ${command}: ${tag}"

    set -- \
        --build-arg "TZ=${TZ}" \
        --build-arg "NGINX_BASE_TAG=${NGINX_BASE_TAG}"
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
