#!/usr/bin/with-contenv bash
# shellcheck shell=bash
set -e

. /usr/libexec/cont-init-common

CRONTAB_PATH="/var/spool/cron/crontabs"
CRON_HOOK_PATH="/data/cron-pre-hook"

LIBRENMS_WEATHERMAP=${LIBRENMS_WEATHERMAP:-false}
LIBRENMS_WEATHERMAP_SCHEDULE=${LIBRENMS_WEATHERMAP_SCHEDULE:-*/5 * * * *}
LIBRENMS_DAILY_SCHEDULE="15 0 * * *"
LIBRENMS_SCHEDULER_SCHEDULE="* * * * *"

SIDECAR_DISPATCHER=${SIDECAR_DISPATCHER:-0}
SIDECAR_SYSLOGNG=${SIDECAR_SYSLOGNG:-0}
SIDECAR_SNMPTRAPD=${SIDECAR_SNMPTRAPD:-0}
DISABLE_CRON=${DISABLE_CRON:-0}

if [ "$SIDECAR_DISPATCHER" = "1" ] || \
   [ "$SIDECAR_SYSLOGNG" = "1" ] || \
   [ "$SIDECAR_SNMPTRAPD" = "1" ] || \
   [ "$DISABLE_CRON" = "1" ] ; then
  exit 0
fi

# Init
rm -rf ${CRONTAB_PATH}
mkdir -m 0755 -p ${CRONTAB_PATH}
touch ${CRONTAB_PATH}/librenms

# Cron
echo "Creating LibreNMS daily.sh cron task with the following period fields: $LIBRENMS_DAILY_SCHEDULE"
echo "${LIBRENMS_DAILY_SCHEDULE} [ -e \"${CRON_HOOK_PATH}\" ] && source \"${CRON_HOOK_PATH}\" ; cd /opt/librenms && bash daily.sh" >>${CRONTAB_PATH}/librenms

echo "Creating LibreNMS scheduler cron task as we are running in a container"
echo "${LIBRENMS_SCHEDULER_SCHEDULE} [ -e \"${CRON_HOOK_PATH}\" ] && source \"${CRON_HOOK_PATH}\" ; cd /opt/librenms && php artisan schedule:run" >>${CRONTAB_PATH}/librenms

if [ "$LIBRENMS_WEATHERMAP" = "true" ] && [ -n "$LIBRENMS_WEATHERMAP_SCHEDULE" ]; then
  echo "Creating LibreNMS Weathermap cron task with the following period fields: $LIBRENMS_WEATHERMAP_SCHEDULE"
  echo "${LIBRENMS_WEATHERMAP_SCHEDULE} [ -e \"${CRON_HOOK_PATH}\" ] && source \"${CRON_HOOK_PATH}\" ; php -f /opt/librenms/html/plugins/Weathermap/map-poller.php" >>${CRONTAB_PATH}/librenms
fi

# Fix perms
echo "Fixing crontabs permissions..."
chmod 0644 ${CRONTAB_PATH}/librenms

# Create service
mkdir -p "${S6_SERVICE_DIR}/cron"
cat >"${S6_SERVICE_DIR}/cron/run" <<EOL
#!/usr/bin/execlineb -P
with-contenv
ifelse { test "${EUID}" -eq "${PUID}" } { /usr/local/bin/supercronic ${CRONTAB_PATH}/librenms } exec busybox crond -f -L /dev/stdout
EOL
chmod +x "${S6_SERVICE_DIR}/cron/run"
