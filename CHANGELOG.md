# 更新记录

## 2026-09-30

### PHP 多版本构建合并

- 新增 `docker-images/php/Dockerfile`，统一 PHP 7.4、8.2、8.3、8.4 和 8.5 的公共构建步骤。
- 删除原有的 `<version>/Dockerfile`；各版本的 `conf.d/`、`extensions/install.sh` 和本地 `.tgz`
  扩展包继续独立维护。保留 PHP 7.4 的 OPcache 配置及 PHP 8.5 的 OPcache 安装处理。
- 新增构建参数 `PHP_VERSION` 和 `PHP_BASE_TAG`，分别选择版本目录和官方基础镜像标签。
  基础镜像的 PHP 主次版本与所选目录不一致时，构建会报错。
- 更新 `build.sh`，使用公共 Dockerfile 构建每个版本；PHP 7.4 继续固定到
  `7.4.33-fpm-alpine`，PHP 8.x 使用 `<version>-fpm-alpine`。缺少版本配置或安装脚本时提前报错。
- 更新 Compose 和 GitHub Actions 的构建入口；CI 继续覆盖全部五个版本，保留 PHP 7.4 的补丁固定、
  扩展检查、FPM 配置检查和健康检查。
- 更新中英文 README、镜像构建说明和 `.env.example`，说明目录结构、参数和迁移方法。
- 新增 `tests/php-build.sh` 并接入 CI，用模拟 Docker 命令验证全部版本的参数、PHP 7.4 基础镜像固定、
  单平台加载、多平台推送、空镜像源、普通推送及无效构建请求。

### 迁移说明

- 使用 `./build.sh build` 或 `./build.sh push` 的流程不变，镜像标签仍按 PHP 版本分别生成。
- 手动构建时，将 `-f <version>/Dockerfile` 改为 `-f Dockerfile`，并传入
  `--build-arg PHP_VERSION=<version>`；构建上下文仍为 `docker-images/php`。
- 手动构建 PHP 7.4 时，额外传入 `--build-arg PHP_BASE_TAG=7.4.33-fpm-alpine`。
- Compose 默认构建 PHP 8.5，可通过 `PHP_VERSION` 切换版本；要固定 PHP 7.4 的基础镜像，使用
  `PHP_VERSION=7.4 PHP_BASE_TAG=7.4.33-fpm-alpine docker compose up --build -d`。
- `PHP_VERSION`、`PHP_BASE_TAG`、`PHP_EXTENSIONS` 和 `ALPINE_MIRROR` 均属于构建参数；
  拉取镜像后设置同名环境变量不会重新选择版本或安装扩展。

### 修复官方镜像版本变量冲突

- 官方 PHP 基础镜像自带完整补丁版本的 `PHP_VERSION` 环境变量，会覆盖构建阶段同名的 `ARG`。
  原检查因此将 `8.5.x` 与目录版本 `8.5` 比较，误报 `PHP_BASE_TAG must match PHP_VERSION`；
  配置及扩展复制路径也会受到影响。
- 在 `FROM` 前将所选版本保存为内部参数 `PHP_TARGET_VERSION`，构建阶段使用该参数执行版本检查、
  选择配置和扩展目录、设置镜像标签信息，保留官方镜像原有的 `PHP_VERSION` 环境变量。
- 外部仍使用 `PHP_VERSION` 和 `PHP_BASE_TAG`，现有构建命令无需修改。
- 真正的版本不匹配错误会同时显示请求版本和基础镜像实际版本，便于定位参数问题。
