#!/usr/bin/with-contenv bash
# shellcheck shell=bash
set -e

. /usr/libexec/cont-init-common

DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-librenms}
DB_USER=${DB_USER:-librenms}
DB_TIMEOUT=${DB_TIMEOUT:-60}

SIDECAR_DISPATCHER=${SIDECAR_DISPATCHER:-0}
SIDECAR_SYSLOGNG=${SIDECAR_SYSLOGNG:-0}
SIDECAR_SNMPTRAPD=${SIDECAR_SNMPTRAPD:-0}
DISABLE_DB_MIGRATE=${DISABLE_DB_MIGRATE:-0}

if [ "$SIDECAR_DISPATCHER" = "1" ] || [ "$SIDECAR_SYSLOGNG" = "1" ] || [ "$SIDECAR_SNMPTRAPD" = "1" ]; then
  exit 0
fi

# Handle .env
if [ ! -f "/data/.env" ]; then
  echo "Generating APP_KEY and unique NODE_ID"
  cat >"/data/.env" <<EOL
APP_KEY=$(artisan key:generate --no-interaction --force --show)
NODE_ID=$(php -r "echo uniqid();")
EOL
fi
cat "/data/.env" >>"${LIBRENMS_PATH}/.env"
if [ "$EUID" = 0 ]; then
  chown librenms:librenms /data/.env "${LIBRENMS_PATH}/.env"
fi

file_env 'DB_PASSWORD'
if [ -z "$DB_PASSWORD" ]; then
  echo >&2 "ERROR: Either DB_PASSWORD or DB_PASSWORD_FILE must be defined"
  exit 1
fi

dbcmd="mariadb -h ${DB_HOST} -P ${DB_PORT} -u "${DB_USER}" "-p${DB_PASSWORD}""
unset DB_PASSWORD

echo "Waiting ${DB_TIMEOUT}s for database to be ready..."
counter=1
while ! ${dbcmd} -e "show databases;" >/dev/null 2>&1; do
  sleep 1
  counter=$((counter + 1))
  if [ ${counter} -gt ${DB_TIMEOUT} ]; then
    echo >&2 "ERROR: Failed to connect to database on $DB_HOST"
    exit 1
  fi
done
echo "Database ready!"

# Enable first run wizard if db is empty
counttables=$(echo 'SHOW TABLES' | ${dbcmd} "$DB_NAME" | wc -l)
if [ "${counttables}" -eq "0" ]; then
  echo "Enabling First Run Wizard..."
  echo "INSTALL=user,finish" >>${LIBRENMS_PATH}/.env
fi

if [ "${DISABLE_DB_MIGRATE}" -ne "1" ] ; then
  echo "Updating database schema..."
  lnms migrate --force --no-ansi --no-interaction
  artisan db:seed --force --no-ansi --no-interaction
else
  echo "Skipping database migration and seeding as DISABLE_DB_MIGRATE is set to 1."
fi

echo "Clear cache"
artisan cache:clear --no-interaction
artisan config:cache --no-interaction

mkdir -p "${S6_SERVICE_DIR}/nginx"
cat >"${S6_SERVICE_DIR}/nginx/run" <<EOL
#!/usr/bin/execlineb -P
with-contenv
${SETUID_CMD}
nginx -g "daemon off;"
EOL
chmod +x "${S6_SERVICE_DIR}/nginx/run"

mkdir -p "${S6_SERVICE_DIR}/php-fpm"
cat >"${S6_SERVICE_DIR}/php-fpm/run" <<EOL
#!/usr/bin/execlineb -P
with-contenv
${SETUID_CMD}
php-fpm83 -F
EOL
chmod +x "${S6_SERVICE_DIR}/php-fpm/run"

mkdir -p "${S6_SERVICE_DIR}/snmpd"
cat >"${S6_SERVICE_DIR}/snmpd/run" <<EOL
#!/usr/bin/execlineb -P
with-contenv
/usr/sbin/snmpd -f -c /etc/snmp/snmpd.conf
EOL
chmod +x "${S6_SERVICE_DIR}/snmpd/run"
