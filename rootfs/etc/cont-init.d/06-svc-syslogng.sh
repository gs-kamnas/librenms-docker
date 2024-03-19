#!/usr/bin/with-contenv bash
# shellcheck shell=bash
set -e

. /usr/libexec/cont-init-common

SIDECAR_SYSLOGNG=${SIDECAR_SYSLOGNG:-0}

# Continue only if sidecar syslogng container
if [ "$SIDECAR_SYSLOGNG" != "1" ]; then
  exit 0
fi

echo ">>"
echo ">> Sidecar syslog-ng container detected"
echo ">>"

mkdir -p /data/syslog-ng /run/syslog-ng
if [ "$EUID" = 0 ]; then
  chown librenms:librenms /data/syslog-ng
  chown -R librenms:librenms /run/syslog-ng
fi

# Create service
mkdir -p "${S6_SERVICE_DIR}/syslogng"
cat >"${S6_SERVICE_DIR}/syslogng/run" <<EOL
#!/usr/bin/execlineb -P
with-contenv
/usr/sbin/syslog-ng -F
EOL
chmod +x "${S6_SERVICE_DIR}/syslogng/run"
