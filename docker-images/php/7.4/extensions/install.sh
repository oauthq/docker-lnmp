#!/bin/sh
set -eu

# Run from this directory so local *.tgz packages are found regardless of cwd
cd "$(dirname "$0")"

export MC="-j$(nproc)"

echo
echo "============================================"
echo "PHP version          : $(php -r 'echo PHP_VERSION;')"
default_extensions="bcmath intl gd gettext mysqli mbstring curl opcache pcntl pdo_mysql redis zip"
builtin_extensions="bcmath calendar exif mysqli opcache pcntl pdo_mysql shmop sockets sysvmsg sysvsem sysvshm"
installer_extensions="amqp apcu ast bz2 curl dba ftp mbstring gd gettext gmp grpc igbinary imagick imap intl ioncube_loader ldap maxminddb mcrypt memcache memcached mongodb msgpack oci8 odbc pdo_dblib pdo_firebird pdo_oci pdo_odbc pdo_pgsql pdo_sqlsrv pgsql phalcon protobuf psr pspell rar rdkafka readline recode redis snmp snuffleupagus soap sourceguardian ssh2 sqlsrv swoole tidy xdebug xhprof xlswriter xmlrpc xsl yaconf yaf yaml yar zend_test zip zookeeper zstd"
requested_extensions="${PHP_EXTENSIONS:-${default_extensions}}"

echo "Requested Extensions : ${requested_extensions}"
echo "Multicore Compiler   : ${MC}"
echo "============================================"
echo

# Fail fast instead of silently ignoring misspelled or unsupported extensions.
set -f
for requested_extension in ${requested_extensions}; do
    case " ${builtin_extensions} ${installer_extensions} " in
        *" ${requested_extension} "*)
            ;;
        *)
            echo "Unsupported PHP extension: ${requested_extension}" >&2
            exit 1
            ;;
    esac
done
set +f

# Normalize space-separated input to a comma-padded CSV for substring checks
export EXTENSIONS=",$(printf '%s' "${requested_extensions}" | tr ' ' ','),"

# Built-in extensions without external build deps via docker-php-ext-install
for ext in ${builtin_extensions}; do
    if [ -z "${EXTENSIONS##*,${ext},*}" ]; then
        echo "---------- Install ${ext} ----------"
        docker-php-ext-install ${MC} ${ext}
    fi
done

# Everything else via docker-php-extension-installer:
# build/runtime deps (icu-dev, libzip-dev, ...), version compatibility and
# cleanup of volatile build deps are handled automatically.
# If a pinned <name>-<version>.tgz exists in this directory, it is installed
# locally instead (offline builds / pinned versions); otherwise the extension
# is downloaded and installed by install-php-extensions.

# Install a pinned PECL package bundled as <name>-<version>.tgz in this directory
installExtensionFromTgz() {
    tgz_file=$1
    shift
    extension_name="${tgz_file%%-*}"
    mkdir -p "${extension_name}"
    tar -xf "${tgz_file}" -C "${extension_name}" --strip-components=1
    ( cd "${extension_name}" && phpize && ./configure "$@" && make ${MC} && make install )
    docker-php-ext-enable "${extension_name}"
}

helper_extensions=""
tgz_extensions=""
for ext in ${installer_extensions}; do
    if [ -z "${EXTENSIONS##*,${ext},*}" ]; then
        tgz_file=$(ls "${ext}"-*.tgz 2>/dev/null | head -n 1 || true)
        if [ -n "${tgz_file}" ]; then
            tgz_extensions="${tgz_extensions} ${tgz_file}"
        else
            helper_extensions="${helper_extensions} ${ext}"
        fi
    fi
done

if [ -n "${tgz_extensions}" ]; then
    # Local tgz builds need the PHP build toolchain. Runtime deps of the
    # extension itself (e.g. libstdc++ for swoole) must be apk-added manually.
    # shellcheck disable=SC2086
    apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS}
    for tgz_file in ${tgz_extensions}; do
        echo "---------- Install ${tgz_file} (local tgz) ----------"
        installExtensionFromTgz "${tgz_file}"
    done
    apk del .build-deps
fi

if [ -n "${helper_extensions}" ]; then
    # shellcheck disable=SC2086
    install-php-extensions ${helper_extensions}
fi
