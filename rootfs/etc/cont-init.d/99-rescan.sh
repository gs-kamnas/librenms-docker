#!/usr/bin/with-contenv sh
# shellcheck shell=sh

# Rescan for services after all initscripts have run
# when running in RO root mode

if [ "$S6_READ_ONLY_ROOT" = 1 ]; then
  . /usr/libexec/cont-init-common
  s6-svscanctl -a "${S6_SERVICE_DIR}"
fi
