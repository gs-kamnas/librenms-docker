#!/usr/bin/with-contenv sh
# shellcheck shell=sh
set -e

echo "Creating runtime directories..."
mkdir -p /data \
  /var/run/nginx \
  /var/run/php-fpm

if [ "$(id -u)" = 0 ]; then
  echo "Fixing perms..."
  chown librenms:librenms \
    /data \
    "${LIBRENMS_PATH}" \
    "${LIBRENMS_PATH}/.env" \
    "${LIBRENMS_PATH}/cache"
  chown -R librenms:librenms \
    /home/librenms \
    /tpls \
    /var/lib/nginx \
    /var/log/nginx \
    /var/log/php83 \
    /var/run/nginx \
    /var/run/php-fpm
fi