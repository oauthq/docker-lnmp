# OAuthQ PHP-FPM 与 Nginx 镜像

[English](README.md)

用于发布到 Docker Hub 的可复用 Alpine PHP-FPM 与 Nginx 运行时镜像。镜像包含运行配置和常用
PHP 扩展，但不包含应用源码。

## 镜像

| 镜像 | 标签 | 基础镜像 | 健康检查 |
| --- | --- | --- | --- |
| `oauthq/php` | `8.2`、`8.3`、`8.4`、`8.5` | 官方 `php:<version>-fpm-alpine` | 内置 FastCGI ping |
| `oauthq/php` | `7.4` | 官方 `php:7.4.33-fpm-alpine` | 内置 FastCGI ping |
| `oauthq/nginx` | `stable` | 官方 `nginx:stable-alpine` | 由下游镜像定义 |

> [!WARNING]
> PHP 7.4 已停止支持，不再获得安全修复。`7.4` 标签仅供遗留项目兼容使用，不属于生产支持版本。

## 特性

- 基于官方 Alpine PHP 和 Nginx 镜像。
- PHP-FPM 使用 UID/GID 为 `1000` 的 `www-data` 用户运行。
- 提供常用 PHP 扩展和独立的版本配置。
- PHP 各版本共用一个 Dockerfile，配置和扩展仍按版本目录维护。
- 每个 PHP 镜像都包含 Composer。
- PHP-FPM 错误和 worker 输出写入容器 stderr。
- PHP 使用 Alpine 维护的系统 CA 证书。
- 构建与健康检查脚本兼容 POSIX `/bin/sh`。
- 支持使用 Docker Buildx 发布多架构镜像。
- CI 验证镜像构建、PHP 扩展、配置和容器启动。

## 快速开始

拉取已发布的镜像：

```sh
docker pull oauthq/php:8.5
docker pull oauthq/nginx:stable
```

在下游 Dockerfile 中使用：

```dockerfile
# PHP 应用镜像
FROM oauthq/php:8.5

COPY --chown=www-data:www-data . /var/www/html
```

```dockerfile
# Nginx 应用镜像
FROM oauthq/nginx:stable

COPY default.conf /etc/nginx/conf.d/default.conf
COPY public/ /var/www/html/public/
```

Nginx 基础镜像保留官方欢迎站点。生产环境必须使用自己的站点配置覆盖
`/etc/nginx/conf.d/default.conf`。

## 使用 Compose 启动本地示例

根目录的 Compose 文件会构建 PHP 和 Nginx 镜像、挂载 `src/` 示例应用并启动本地 HTTP 服务：

```sh
docker compose up --build -d
curl http://localhost:8080
docker compose ps
```

接口返回包含 PHP 版本和部分扩展状态的 JSON。可以通过 `HTTP_PORT` 修改宿主机端口，通过
`PHP_VERSION` 选择 `7.4`、`8.2`、`8.3`、`8.4` 或 `8.5`：

```sh
HTTP_PORT=8083 PHP_VERSION=8.3 docker compose up --build -d
```

Compose 使用 `docker-images/php/Dockerfile`。`PHP_VERSION` 选择版本目录，
`PHP_BASE_TAG` 可指定同一 PHP 版本的补丁或 Alpine 镜像标签。PHP 7.4 固定版本的示例：

```sh
PHP_VERSION=7.4 PHP_BASE_TAG=7.4.33-fpm-alpine docker compose up --build -d
```

停止并删除本地容器和网络：

```sh
docker compose down
```

## 本地构建

### PHP

```sh
cd docker-images/php
cp .env.example .env
```

在 `.env` 中设置：

```dotenv
IMAGE_NAMESPACE=oauthq
PHP_VERSIONS="8.2 8.3 8.4 8.5"
PHP_EXTENSIONS="bcmath intl gd gettext mysqli mbstring curl opcache pcntl pdo_mysql redis zip"
PLATFORMS=""
```

将镜像构建到本地 Docker 镜像存储：

```sh
./build.sh build
```

所有 PHP 版本统一使用 `docker-images/php/Dockerfile`。脚本为每个版本传入 `PHP_VERSION`
和 `PHP_BASE_TAG`：PHP 7.4 使用 `7.4.33-fpm-alpine`，PHP 8.x 使用
`<version>-fpm-alpine`。各版本的 `conf.d/`、`extensions/`、本地扩展包以及 PHP 8.5
的 OPcache 处理仍独立保留。

在 `docker-images/php` 目录手动构建单个版本：

```sh
docker build --build-arg PHP_VERSION=8.3 -t oauthq/php:8.3 .
```

手动构建 PHP 7.4 时，还需传入 `--build-arg PHP_BASE_TAG=7.4.33-fpm-alpine` 保持补丁版本固定。
基础镜像的 PHP 主次版本必须与所选目录一致。这些是构建参数，拉取镜像后设置同名环境变量
不会改变 PHP 版本或已安装的扩展。
Dockerfile 在 `FROM` 后使用内部参数 `PHP_TARGET_VERSION`，避免官方基础镜像的 `PHP_VERSION`
环境变量覆盖所选目录。外部构建命令仍传入 `PHP_VERSION`，无需增加参数。

### Nginx

```sh
cd docker-images/nginx
cp .env.example .env
```

在 `.env` 中设置：

```dotenv
IMAGE_NAMESPACE=oauthq
NGINX_VERSIONS="stable"
PLATFORMS=""
```

然后构建：

```sh
./build.sh build
```

## 发布到 Docker Hub

先在 Docker Hub 创建 `oauthq/php` 和 `oauthq/nginx` 仓库，然后登录：

```sh
docker login
```

如需发布多架构镜像，在两个镜像目录的 `.env` 中设置：

```dotenv
PLATFORMS="linux/amd64,linux/arm64"
```

分别推送 PHP 和 Nginx：

```sh
cd docker-images/php
./build.sh push

cd ../nginx
./build.sh push
```

仅配置一个平台时，`build` 使用 `buildx --load` 加载到本地。多个平台无法载入传统的本地
Docker 镜像存储，必须使用 `push` 发布。

## PHP 扩展

默认扩展：

```text
bcmath intl gd gettext mysqli mbstring curl opcache pcntl pdo_mysql redis zip
```

在 `docker-images/php/.env` 中设置 `PHP_EXTENSIONS` 可以整体替换默认列表。未知或拼写错误的
扩展名称会中止构建。

下游镜像可以继续安装受支持的扩展：

```dockerfile
FROM oauthq/php:8.5

USER root
RUN install-php-extensions apcu imagick pdo_pgsql
USER www-data
```

扩展目录和高级构建选项见 [docker-images/README.md](docker-images/README.md)。

## 健康检查

PHP 镜像内置 FastCGI 健康检查，脚本默认值如下：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `FCGI_CONNECT` | `127.0.0.1:9000` | PHP-FPM FastCGI 地址 |
| `FCGI_PING_PATH` | `/ping` | 必须与 FPM `ping.path` 一致的请求路径 |

它们是运行时环境变量。修改变量不会自动重写 PHP-FPM 配置，因此下游覆盖 FPM 配置时，必须保证
`listen`、`ping.path` 和健康检查变量保持一致。

PHP 健康检查只验证 PHP-FPM 与 FastCGI 是否可用，不验证应用、数据库、Redis 或其他依赖。

Nginx 镜像不声明 Docker `HEALTHCHECK`，因为最终协议、端口、路由和就绪条件由下游镜像决定。
镜像保留了可选的 `nginx-healthcheck` 脚本，用于基础 HTTP 存活检查。

## 仓库结构

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

## 更新记录

构建合并和迁移说明见 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。内置的
[`docker-php-extension-installer`](https://github.com/mlocati/docker-php-extension-installer)
也使用其自身的 MIT 许可证。
