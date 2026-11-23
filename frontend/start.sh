#!/bin/sh
# Render the nginx config from the template and run nginx in the foreground.
set -eu
: "${PORT:=8080}"
: "${BACKEND_HOST:?BACKEND_HOST is not set (the Backend service private domain)}"
: "${BACKEND_PORT:=8000}"
# Railway's private DNS server (IPv6 on Railway); nginx needs it in brackets.
NS=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
case "$NS" in *:*) NS="[$NS]";; esac
export PORT BACKEND_HOST BACKEND_PORT
sed -e "s|__PORT__|$PORT|g" -e "s|__RESOLVER__|$NS|g" \
    -e "s|__BACKEND__|$BACKEND_HOST:$BACKEND_PORT|g" \
    /etc/unstract/nginx.conf.template > /tmp/nginx.conf
# Upstream's runtime-config.js generator (version shown on the profile page).
/docker-entrypoint.d/40-env.sh >/dev/null
nginx -t -c /tmp/nginx.conf -q
exec nginx -c /tmp/nginx.conf -g 'daemon off;'
