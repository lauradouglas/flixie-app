#!/bin/sh
set -eu

case "${CONFIGURATION:-}" in Release*) ;; *) exit 0 ;; esac

# Mirror ApiClient's release default while rejecting local archive overrides.
api_url=''
use_prod_api=true
saved_ifs=$IFS
IFS=,
for encoded in ${DART_DEFINES:-}; do
  decoded=$(printf '%s' "$encoded" | /usr/bin/base64 --decode)
  case "$decoded" in
    API_BASE_URL=*) api_url=${decoded#API_BASE_URL=} ;;
    USE_PROD_API=*) use_prod_api=${decoded#USE_PROD_API=} ;;
  esac
done
IFS=$saved_ifs
if [ -z "$api_url" ]; then
  if [ "$use_prod_api" = false ]; then
    api_url=http://localhost:3000
  else
    api_url=https://flixie-api-fmcehvaecwdheccm.northeurope-01.azurewebsites.net
  fi
fi
case "$api_url" in
  https://*) ;;
  *) echo 'error: Release builds require an HTTPS API_BASE_URL. Build with --dart-define-from-file=<release config>.' >&2; exit 1 ;;
esac
host=${api_url#https://}
host=${host%%/*}
case "$host" in
  ''|localhost*|127.*|192.168.*|10.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|\[::1\]*|*.local|*.local:*|*@*)
    echo 'error: API_BASE_URL must use the public release backend.' >&2; exit 1 ;;
esac
