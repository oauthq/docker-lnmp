# OAuthQ PHP-FPM and Nginx Images

[简体中文](readme_zh.md)

Reusable Alpine-based PHP-FPM and Nginx runtime images for Docker Hub. The images contain
runtime configuration and common PHP extensions, but no application source code.

## Images

| Image | Tags | Base | Healthcheck |
| --- | --- | --- | --- |
| `oauthq/php` | `8.2`, `8.3`, `8.4`, `8.5` | Official `php:<version>-fpm-alpine` | Built-in FastCGI ping |
| `oauthq/php` | `7.4` | Official `php:7.4.33-fpm-alpine` | Built-in FastCGI ping |
| `oauthq/nginx` | `stable` | Official `nginx:stable-alpine` | Defined by downstream images |

> [!WARNING]
> PHP 7.4 reached end of life and no longer receives security fixes. The `7.4` tag is
> provided only for legacy workloads and is not a production-supported runtime.

## Features

- Official Alpine-based PHP and Nginx base images.
- PHP-FPM runs as `www-data` with UID/GID `1000`.
- Common PHP extensions with per-version configuration.
- One shared PHP Dockerfile, with separate configuration and extension directories per version.
- Composer included in every PHP image.
- PHP-FPM errors and worker output sent to container stderr.
- Alpine's maintained system CA bundle used by PHP.
- POSIX `/bin/sh` build and healthcheck scripts.
- Optional multi-platform publishing with Docker Buildx.
- CI validation for image builds, PHP extensions, configuration, and container startup.

## Quick start

Pull published images:

```sh
docker pull oauthq/php:8.5
docker pull oauthq/nginx:stable
```

Use them in downstream Dockerfiles:

```dockerfile
# PHP application image
FROM oauthq/php:8.5

COPY --chown=www-data:www-data . /var/www/html
```

```dockerfile
# Nginx application image
FROM oauthq/nginx:stable

COPY default.conf /etc/nginx/conf.d/default.conf
COPY public/ /var/www/html/public/
```

The Nginx base image retains the official welcome site. Production consumers must replace
`/etc/nginx/conf.d/default.conf` with their own server configuration.

## Local demo with Compose

The root Compose file builds both images, mounts the sample application from `src/`, and
starts a local HTTP service:

```sh
docker compose up --build -d
curl http://localhost:8080
docker compose ps
```

The response is JSON containing the PHP version and selected extension status. Use
`HTTP_PORT` to change the host port or `PHP_VERSION` to select `7.4`, `8.2`, `8.3`,
`8.4`, or `8.5`:

```sh
HTTP_PORT=8083 PHP_VERSION=8.3 docker compose up --build -d
```

Compose uses `docker-images/php/Dockerfile`. `PHP_VERSION` selects the version directory;
`PHP_BASE_TAG` can select a matching patch or Alpine base tag. For the pinned legacy base:

```sh
PHP_VERSION=7.4 PHP_BASE_TAG=7.4.33-fpm-alpine docker compose up --build -d
```

Stop and remove the local containers and network:

```sh
docker compose down
```

## Build locally

### PHP

```sh
cd docker-images/php
cp .env.example .env
```

Set the required values in `.env`:

```dotenv
IMAGE_NAMESPACE=oauthq
PHP_VERSIONS="8.2 8.3 8.4 8.5"
PHP_EXTENSIONS="bcmath intl gd gettext mysqli mbstring curl opcache pcntl pdo_mysql redis zip"
PLATFORMS=""
```

Build images into the local Docker image store:

```sh
./build.sh build
```

All PHP versions now use `docker-images/php/Dockerfile`. The script passes `PHP_VERSION`
and `PHP_BASE_TAG` for each image, using `7.4.33-fpm-alpine` for PHP 7.4 and
`<version>-fpm-alpine` for PHP 8.x. Each version keeps its own `conf.d/` and `extensions/`
directories, including local extension packages and the PHP 8.5 OPcache handling.

To build one version manually from `docker-images/php`:

```sh
docker build --build-arg PHP_VERSION=8.3 -t oauthq/php:8.3 .
```

For PHP 7.4, also pass `--build-arg PHP_BASE_TAG=7.4.33-fpm-alpine` to retain the patch pin.
The base image must match the selected PHP major/minor version. These are build arguments;
setting them after pulling an image does not change its PHP version or installed extensions.
The Dockerfile uses an internal `PHP_TARGET_VERSION` argument after `FROM` to avoid the
official base image's `PHP_VERSION` environment variable overriding the selected directory.
Keep passing `PHP_VERSION` in your build commands; no additional argument is required.

### Nginx

```sh
cd docker-images/nginx
cp .env.example .env
```

Set the required values in `.env`:

```dotenv
IMAGE_NAMESPACE=oauthq
NGINX_VERSIONS="stable"
PLATFORMS=""
```

Then build:

```sh
./build.sh build
```

## Publish to Docker Hub

Create the `oauthq/php` and `oauthq/nginx` repositories in Docker Hub, then authenticate:

```sh
docker login
```

For multi-platform publishing, set this value in each image's `.env`:

```dotenv
PLATFORMS="linux/amd64,linux/arm64"
```

Push PHP and Nginx separately:

```sh
cd docker-images/php
./build.sh push

cd ../nginx
./build.sh push
```

With one configured platform, `build` uses `buildx --load`. Multiple platforms cannot be
loaded into the classic local Docker image store and must be published with `push`.

## PHP extensions

Default extensions:

```text
bcmath intl gd gettext mysqli mbstring curl opcache pcntl pdo_mysql redis zip
```

Set `PHP_EXTENSIONS` in `docker-images/php/.env` to replace the complete default list.
Unknown or misspelled extension names stop the build.

Downstream images can install additional supported extensions:

```dockerfile
FROM oauthq/php:8.5

USER root
RUN install-php-extensions apcu imagick pdo_pgsql
USER www-data
```

See [docker-images/README.md](docker-images/README.md) for the extension catalog and advanced
build options.

## Healthchecks

PHP images include a FastCGI healthcheck with these script defaults:

| Variable | Default | Description |
| --- | --- | --- |
| `FCGI_CONNECT` | `127.0.0.1:9000` | PHP-FPM FastCGI endpoint |
| `FCGI_PING_PATH` | `/ping` | Request path matching FPM `ping.path` |

These are runtime environment variables. Changing them does not rewrite the PHP-FPM
configuration, so downstream FPM overrides must keep `listen`, `ping.path`, and the
healthcheck variables aligned.

The PHP healthcheck verifies only PHP-FPM and FastCGI availability. It does not verify the
application, database, Redis, or other dependencies.

The Nginx image intentionally declares no Docker `HEALTHCHECK`, because downstream images
own the final protocol, port, route, and readiness requirements. An optional
`nginx-healthcheck` helper is included for basic HTTP liveness checks.

## Repository layout

```text
docker-images/
├── php/
│   ├── Dockerfile
│   ├── 7.4/
│   ├── 8.2/
│   ├── 8.3/
│   ├── 8.4/
│   ├── 8.5/
│   ├── build.sh
│   ├── healthcheck.sh
│   ├── install-php-extensions
│   └── php-fpm.conf
├── nginx/
│   ├── stable/
│   ├── conf/nginx.conf
│   ├── build.sh
│   └── healthcheck.sh
└── README.md
```

## Change history

See [CHANGELOG.md](CHANGELOG.md) for the build consolidation and migration notes.

## License

This project is distributed under the [MIT License](LICENSE). The bundled
[`docker-php-extension-installer`](https://github.com/mlocati/docker-php-extension-installer)
is also distributed under its own MIT license.
