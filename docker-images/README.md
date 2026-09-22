# Docker Images

Reusable PHP-FPM and Nginx runtime images built on official Alpine-based images.

## Structure

```
docker-images/
├── nginx/
│   ├── conf/
│   │   └── nginx.conf
│   ├── stable/
│   │   └── Dockerfile
│   ├── build.sh
│   └── healthcheck.sh
├── php/
│   ├── 7.4/
│   │   ├── Dockerfile
│   │   ├── conf.d/
│   │   │   ├── 20-opcache.ini
│   │   │   └── 99-company.ini
│   │   └── extensions/
│   │       └── install.sh              # version-specific extension installer
│   ├── 8.2/
│   │   ├── Dockerfile
│   │   ├── conf.d/
│   │   │   ├── 20-opcache.ini
│   │   │   └── 99-company.ini
│   │   └── extensions/
│   │       └── install.sh              # version-specific extension installer
│   ├── 8.3/
│   │   ├── Dockerfile
│   │   ├── conf.d/
│   │   │   ├── 20-opcache.ini
│   │   │   └── 99-company.ini
│   │   └── extensions/
│   │       └── install.sh              # version-specific extension installer
│   ├── 8.4/
│   │   ├── Dockerfile
│   │   ├── conf.d/
│   │   │   ├── 20-opcache.ini
│   │   │   └── 99-company.ini
│   │   └── extensions/
│   │       └── install.sh              # version-specific extension installer
│   └── 8.5/
│       ├── Dockerfile
│       ├── conf.d/
│       │   ├── 20-opcache.ini
│       │   └── 99-company.ini
│       └── extensions/
│           └── install.sh              # version-specific extension installer
│
├── php/install-php-extensions   # shared docker-php-extension-installer tool
├── php/php-fpm.conf             # shared FPM pool tuning
├── php/healthcheck.sh           # shared healthcheck
├── php/build.sh                 # build/push loop driven by .env
├── php/.env.example             # build params template
└── README.md
```

## Design notes

- **One build directory per PHP version** — each `Dockerfile` pins its own base image, so
  versions evolve independently (different extensions, different build flags).
- **Build context is `php/`** — shared assets (`install-php-extensions`, `php-fpm.conf`,
  `healthcheck.sh`) live outside the version directories and are copied from the context root.
- **Config is additive** — every version dir ships only `conf.d/` fragments, merged on top of
  the base image's `php.ini`. `20-*` loads first, `99-*` wins. No whole-file override of `php.ini`.
- **Extensions installed by `install-php-extensions`** (mlocati/docker-php-extension-installer):
  resolves build/runtime dependencies, version compatibility and cleanup automatically.
- **No application code** — this is a reusable runtime image; bake your app in a downstream
  `FROM yourhub/php:8.5` Dockerfile or mount it at `/var/www/html`.
- **The nginx image is a base runtime** — it retains the official nginx welcome site so the
  base image can run standalone, but ships no Laravel site config. Production consumers must
  replace `/etc/nginx/conf.d/default.conf` with their own configuration.
- **`www-data` is re-mapped to uid/gid 1000** so mounted source files match your host user.
- **System CA bundle** — PHP `curl.cainfo` / `openssl.cafile` use Alpine's maintained
  `/etc/ssl/certs/ca-certificates.crt`; no additional CA file is downloaded during the build.
- **Container-native logs** — php-fpm writes its error and worker output to stderr so it is
  available through `docker logs`. Downstream may override this for external log storage.

> [!WARNING]
> PHP 7.4 is end-of-life and receives no security fixes. The 7.4 image is provided only for
> legacy workloads and must not be treated as a production-supported runtime.

## Build and push

```sh
# in docker-images/php
cp .env.example .env     # adjust IMAGE_NAMESPACE / PHP_VERSIONS / TZ / CONTAINER_PACKAGE_URL
chmod +x build.sh

./build.sh build         # docker build every version listed in PHP_VERSIONS
./build.sh push          # docker push every version
```

Configurable via `.env`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `IMAGE_NAMESPACE` | `yourhub` | image tag prefix, tag = `${IMAGE_NAMESPACE}/php:<version>` |
| `PHP_VERSIONS` | `8.5` | space-separated versions to build/push |
| `COMPOSER_VERSION` | `2.8` | composer builder-stage image tag (minor pin) |
| `TZ` | `Asia/Shanghai` | container timezone |
| `CONTAINER_PACKAGE_URL` | *(empty)* | Alpine apk mirror host, e.g. `mirrors.ustc.edu.cn` |
| `PLATFORMS` | *(empty)* | multi-arch platforms for buildx, e.g. `linux/amd64,linux/arm64` |

Or build a single version manually:

```sh
docker build -f 8.5/Dockerfile --build-arg TZ=UTC -t yourhub/php:8.5 .
```

### Multi-architecture (buildx)

To publish multi-arch images to a registry (e.g. Docker Hub), use buildx with
`--platform` and `--push` instead of plain `docker build`:

```sh
docker buildx build --platform linux/amd64,linux/arm64 \
    -f 8.5/Dockerfile -t yourhub/php:8.5 --push .
```

When `PLATFORMS` contains one platform, `./build.sh build` uses `buildx --load` so the
image appears in the local Docker image store. Multiple platforms cannot be loaded into
the classic local image store, so `./build.sh build` fails with a clear message and
`./build.sh push` must be used instead.

## Extensions

Extensions are owned **per PHP version**:

- `php/<version>/extensions/install.sh` is that version's own install script.
  The extension catalog matches the reference build script:
  - **dep-free built-ins** via `docker-php-ext-install`: `bcmath calendar exif mysqli
    opcache pcntl pdo_mysql shmop sockets sysvmsg sysvsem sysvshm`
  - **everything else** (gd, intl, zip, pgsql, redis, amqp, memcached, swoole, xdebug,
    imagick, mongodb, pspell, ...) via the shared `install-php-extensions` tool, which resolves
    build/runtime deps, version compatibility and cleans up volatile build deps itself.
  - **pinned offline packages** — drop `<name>-<version>.tgz` (e.g. `redis-5.3.7.tgz`) into
    `php/<version>/extensions/`; install.sh detects it and compiles from the local package
    instead of downloading (one tgz per extension; unknown extensions still fall back to the
    installer).
- `.env`'s `PHP_EXTENSIONS` overrides the list for all versions at build time
  (`--build-arg PHP_EXTENSIONS="gd xdebug"`); leave it empty to use the per-version
  defaults inside the scripts.

Per-version default list:

`bcmath`, `intl`, `gd`, `gettext`, `mysqli`, `mbstring`, `curl`, `opcache`, `pcntl`,
`pdo_mysql`, `redis`, `zip`.

Unknown or misspelled extension names fail the build instead of being silently ignored.

Extensions from the reference script that need custom handling (not wired to the shared
installer, e.g. `seaslog`, `varnish`, `sdebug`, `hprose`, `yac`) can be added manually
in a version's `install.sh` if ever needed.

## Runtime usage

These are base images intended for downstream `FROM` use. Nginx ships no Laravel site
config by default — mount or copy your own `default.conf` into `/etc/nginx/conf.d/`.

```yaml
services:
  php:
    image: yourhub/php:8.5
    volumes:
      - ./src:/var/www/html
    # optional: override config without rebuilding
    #  - ./custom.ini:/usr/local/etc/php/conf.d/99-company.ini

  nginx:
    image: yourhub/nginx:stable
    ports:
      - "8080:80"
    volumes:
      - ./src:/var/www/html
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
```

Downstream Dockerfile examples:

```dockerfile
# php: add extensions and code
FROM yourhub/php:8.5
USER root
RUN install-php-extensions gd pgsql
USER www-data
COPY src/ /var/www/html/

# nginx: bake the site config
FROM yourhub/nginx:stable
COPY default.conf /etc/nginx/conf.d/default.conf
COPY src/public/ /var/www/html/public/
```

### Entrypoint behavior

The image uses the official `docker-php-entrypoint` (`ENTRYPOINT ["docker-php-entrypoint"]`,
`CMD ["php-fpm"]`):

| Command | Result |
| --- | --- |
| `docker run img` | starts `php-fpm` |
| `docker run img -m` | auto-prepends `php-fpm`: runs `php-fpm -m` (works for any `-`-prefixed flag) |
| `docker run img php artisan migrate --force` | args passed through unchanged |

## Healthcheck

The built-in healthcheck probes php-fpm `ping.path` over FastCGI (requires the `fcgi`
package). Override via environment without rebuilding:

| Variable | Default | Purpose |
| --- | --- | --- |
| `FCGI_CONNECT` | `127.0.0.1:9000` | php-fpm FastCGI endpoint |
| `FCGI_PING_PATH` | `/ping` | ping URI, must match `ping.path` in php-fpm.conf |

The healthcheck script supplies these defaults when the variables are unset. They are
runtime environment variables, not Docker build arguments, and can be overridden with
`docker run -e` or Compose `environment`. Changing them only changes the healthcheck
request: it does not rewrite the php-fpm configuration. If a downstream image changes
the FPM listen address or ping path, both sides must be updated together:

```yaml
services:
  php:
    image: yourhub/php:8.5
    environment:
      FCGI_CONNECT: "127.0.0.1:9001"
      FCGI_PING_PATH: "/fpm-health"
```

```ini
; downstream php-fpm.d override
[www]
listen = 0.0.0.0:9001
ping.path = /fpm-health
```

This healthcheck verifies only that php-fpm can handle a FastCGI ping. It does not
verify Laravel, a database, Redis, or any other application dependency.

The nginx base image intentionally does not declare a Docker `HEALTHCHECK`, because the
final protocol, port, path, and application dependencies are owned by the downstream
image. The optional `/usr/local/bin/nginx-healthcheck` helper remains available, but it
only verifies that nginx returns an HTTP response; production consumers should define a
healthcheck against their own endpoint.

## Adding a new PHP version

```sh
mkdir -p php/8.6/conf.d php/8.6/extensions
cp php/8.5/Dockerfile php/8.6/Dockerfile   # then: base image 8.6, label, conf.d path
cp php/8.5/conf.d/* php/8.6/conf.d/
cp php/8.5/extensions/install.sh php/8.6/extensions/
```
