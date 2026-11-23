#!/bin/bash
# Creates a self-signed TLS certificate on the volume on first boot (clients such as
# Unstract's Postgres vector DB adapter ask for SSL by default), then hands over to
# the official entrypoint. Sized for a small Railway service.
set -euo pipefail
CERT_DIR=/var/lib/postgresql/data/certs
if [ ! -s "$CERT_DIR/server.key" ]; then
  mkdir -p "$CERT_DIR"
  openssl req -new -x509 -days 3650 -nodes -subj "/CN=postgres.railway.internal" \
    -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" >/dev/null 2>&1
  chmod 600 "$CERT_DIR/server.key"
fi
chown -R postgres:postgres "$CERT_DIR"
exec docker-entrypoint.sh postgres \
  -c listen_addresses='*' \
  -c max_connections=200 \
  -c shared_buffers=128MB \
  -c ssl=on \
  -c ssl_cert_file="$CERT_DIR/server.crt" \
  -c ssl_key_file="$CERT_DIR/server.key"
