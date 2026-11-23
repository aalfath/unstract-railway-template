#!/bin/bash
# Railway start script for the Unstract backend (unstract/backend:v0.204.0).
set -euo pipefail
cd /app

# Upstream's images hard-link llama_index's bundled nltk stopwords to the uv cache, and
# nltk's path guard refuses hard-linked files ("refusing multiply-linked file"), so every
# vector DB test and indexing run fails. Use a private copy (one link per file) instead.
export NLTK_DATA="${NLTK_DATA:-/tmp/nltk_data}"
if [ ! -d "$NLTK_DATA/corpora" ]; then
  rm -r "$NLTK_DATA.tmp" 2>/dev/null || true
  cp -r /app/.venv/lib/python3.12/site-packages/llama_index/core/_static/nltk_cache "$NLTK_DATA.tmp"
  mv "$NLTK_DATA.tmp" "$NLTK_DATA"
fi
# Defaults that never need changing on Railway (kept out of the template variables).
export DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-backend.settings.dev}"
export PATH_PREFIX="${PATH_PREFIX:-api/v1}"
export DB_SCHEMA="${DB_SCHEMA:-unstract}"
export DB_PORT="${DB_PORT:-5432}"
export REDIS_PORT="${REDIS_PORT:-6379}"
export REDIS_USER="${REDIS_USER:-default}"
export LOG_TRANSPORT=redis
export PG_SCHEDULER_ADOPT_PERIODICS=true
export SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE:-True}"
export CSRF_COOKIE_SECURE="${CSRF_COOKIE_SECURE:-True}"
export SESSION_COOKIE_AGE="${SESSION_COOKIE_AGE:-86400}"
export ENABLE_LOG_HISTORY="${ENABLE_LOG_HISTORY:-True}"
export LOG_HISTORY_CONSUMER_INTERVAL="${LOG_HISTORY_CONSUMER_INTERVAL:-30}"
export LOGS_BATCH_LIMIT="${LOGS_BATCH_LIMIT:-30}"
export LOGS_EXPIRATION_TIME_IN_SECOND="${LOGS_EXPIRATION_TIME_IN_SECOND:-86400}"
export INDEXING_FLAG_TTL="${INDEXING_FLAG_TTL:-1800}"
export NOTIFICATION_TIMEOUT="${NOTIFICATION_TIMEOUT:-5}"
export FLIPT_SERVICE_AVAILABLE=False
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
export STRUCTURE_TOOL_IMAGE_URL="${STRUCTURE_TOOL_IMAGE_URL:-docker:unstract/tool-structure:0.0.101}"
export STRUCTURE_TOOL_IMAGE_NAME="${STRUCTURE_TOOL_IMAGE_NAME:-unstract/tool-structure}"
export STRUCTURE_TOOL_IMAGE_TAG="${STRUCTURE_TOOL_IMAGE_TAG:-0.0.101}"
export TOOL_REGISTRY_CONFIG_PATH="${TOOL_REGISTRY_CONFIG_PATH:-/unstract/tool-registry/tool_registry_config}"
export TOOL_REGISTRY_STORAGE_CREDENTIALS='{"provider":"local"}'
export PROMPT_STUDIO_FILE_PATH="${PROMPT_STUDIO_FILE_PATH:-/tmp/prompt-studio-data}"
export REMOTE_PROMPT_STUDIO_FILE_PATH="${REMOTE_PROMPT_STUDIO_FILE_PATH:-unstract/prompt-studio-data}"
export WORKFLOW_EXECUTION_DIR_PREFIX="${WORKFLOW_EXECUTION_DIR_PREFIX:-unstract/execution}"
export API_EXECUTION_DIR_PREFIX="${API_EXECUTION_DIR_PREFIX:-unstract/api}"
export AGENT_KV_STORAGE_DIR_PREFIX="${AGENT_KV_STORAGE_DIR_PREFIX:-unstract/agent_kv}"
export PLATFORM_SERVICE_PORT="${PLATFORM_SERVICE_PORT:-3001}"
export X2TEXT_PORT="${X2TEXT_PORT:-3004}"
export SYSTEM_ADMIN_USERNAME="${SYSTEM_ADMIN_USERNAME:-admin}"
export SYSTEM_ADMIN_EMAIL="${SYSTEM_ADMIN_EMAIL:-admin@example.com}"
# Railway private networking is IPv6; the internal URLs use the service hostnames.
export PLATFORM_SERVICE_HOST="${PLATFORM_SERVICE_HOST:-http://${PLATFORM_HOST:?PLATFORM_HOST is not set}}"
export X2TEXT_HOST="${X2TEXT_HOST:-http://${X2TEXT_HOSTNAME:?X2TEXT_HOSTNAME is not set}}"
# Celery is only a transport stub since UN-4046 (every dispatch goes through Postgres
# queues); point it at Redis db 1 so no RabbitMQ is needed.
export CELERY_BROKER_BASE_URL="${CELERY_BROKER_BASE_URL:-redis://${REDIS_HOST}:${REDIS_PORT}/1}"
export CELERY_BROKER_USER="${CELERY_BROKER_USER:-$REDIS_USER}"
export CELERY_BROKER_PASS="${CELERY_BROKER_PASS:-${REDIS_PASSWORD:-}}"
# One storage JSON for every storage role, built from the MinIO variables.
storage_json=$(.venv/bin/python -c 'import json,os;print(json.dumps({"provider":"minio","credentials":{"endpoint_url":os.environ["MINIO_ENDPOINT"],"key":os.environ["MINIO_ACCESS_KEY"],"secret":os.environ["MINIO_SECRET_KEY"]}}))')
for v in WORKFLOW_EXECUTION_FILE_STORAGE_CREDENTIALS API_FILE_STORAGE_CREDENTIALS PERMANENT_REMOTE_STORAGE TEMPORARY_REMOTE_STORAGE HITL_FILES_FILE_STORAGE_CREDENTIALS AGENT_KV_FILE_STORAGE_CREDENTIALS; do
  export "$v=$storage_json"
done
# Web origin: the public domain of the Unstract (web) service.
if [ -n "${WEB_APP_ORIGIN_URL:-}" ]; then :; elif [ -n "${PUBLIC_DOMAIN:-}" ]; then
  export WEB_APP_ORIGIN_URL="https://${PUBLIC_DOMAIN}"
fi
export DJANGO_APP_BACKEND_URL="${DJANGO_APP_BACKEND_URL:-${WEB_APP_ORIGIN_URL:-http://localhost:8000}}"
export GUNICORN_WORKERS="${GUNICORN_WORKERS:-1}"
export GUNICORN_THREADS="${GUNICORN_THREADS:-64}"

for v in DB_HOST DB_USER DB_PASSWORD DB_NAME REDIS_HOST DJANGO_SECRET_KEY ENCRYPTION_KEY INTERNAL_SERVICE_API_KEY DEFAULT_AUTH_PASSWORD SYSTEM_ADMIN_PASSWORD; do
  if [ -z "${!v:-}" ]; then echo "Missing required variable $v" >&2; exit 1; fi
done

# First-run setup (upstream does these in an initdb script and the minio-bootstrap
# container): schema + pgvector extension, MinIO bucket. Guarded by an advisory lock
# so two overlapping deploys never migrate at the same time.
.venv/bin/python - <<'PY'
import os, sys, time
import psycopg2
for attempt in range(120):
    try:
        conn = psycopg2.connect(host=os.environ["DB_HOST"], port=os.environ["DB_PORT"],
            user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
            dbname=os.environ["DB_NAME"], connect_timeout=5)
        break
    except psycopg2.OperationalError as e:
        if attempt % 10 == 0:
            print("waiting for Postgres...", flush=True)
        time.sleep(2)
else:
    sys.exit("Postgres never became reachable")
conn.autocommit = True
schema = os.environ["DB_SCHEMA"].replace('"', "")
with conn.cursor() as cur:
    cur.execute(f'CREATE SCHEMA IF NOT EXISTS "{schema}"')
    try:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
    except Exception as e:  # pgvector is optional for the app itself
        print(f"pgvector extension not created: {e}", flush=True)
conn.close()
print(f"database ready (schema {schema})", flush=True)

import s3fs
for attempt in range(120):
    try:
        fs = s3fs.S3FileSystem(key=os.environ["MINIO_ACCESS_KEY"], secret=os.environ["MINIO_SECRET_KEY"],
                               client_kwargs={"endpoint_url": os.environ["MINIO_ENDPOINT"]})
        if not fs.exists("unstract"):
            fs.mkdir("unstract")
        print("MinIO bucket ready", flush=True)
        break
    except Exception as e:
        if attempt % 10 == 0:
            print(f"waiting for MinIO ({e.__class__.__name__})...", flush=True)
        time.sleep(2)
else:
    sys.exit("MinIO bucket could not be created")
PY

mkdir -p "$PROMPT_STUDIO_FILE_PATH"

echo "Running migrations (under a Postgres advisory lock)"
.venv/bin/python - <<'PY'
import os, subprocess, sys
import psycopg2
conn = psycopg2.connect(host=os.environ["DB_HOST"], port=os.environ["DB_PORT"],
    user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"], dbname=os.environ["DB_NAME"])
conn.autocommit = True
cur = conn.cursor()
# Poll with pg_try_advisory_lock: a blocking pg_advisory_lock keeps a transaction open
# while it waits, and the migrations' CREATE INDEX CONCURRENTLY then waits for that
# transaction forever (deadlock between overlapping deploys).
import time
while True:
    cur.execute("SELECT pg_try_advisory_lock(729891)")
    if cur.fetchone()[0]:
        break
    print("another deploy is migrating; waiting", flush=True)
    time.sleep(5)
try:
    # A migration cut short (e.g. Postgres restarted) leaves CREATE INDEX CONCURRENTLY
    # indexes INVALID, and the re-run then fails with "already exists": drop them.
    cur.execute("""SELECT format('%%I.%%I', n.nspname, c.relname) FROM pg_index i
                   JOIN pg_class c ON c.oid = i.indexrelid JOIN pg_namespace n ON n.oid = c.relnamespace
                   WHERE NOT i.indisvalid AND n.nspname = %s""", (os.environ["DB_SCHEMA"],))
    for (idx,) in cur.fetchall():
        print(f"dropping invalid index {idx} left by an interrupted migration", flush=True)
        cur.execute(f"DROP INDEX IF EXISTS {idx}")
    rc = subprocess.call([".venv/bin/python", "manage.py", "migrate", "--no-input", "-v", "0"])
    if rc != 0:
        sys.exit(rc)
    flag = ["--periodics"] if os.environ.get("PG_SCHEDULER_ADOPT_PERIODICS", "").lower() == "true" else []
    subprocess.call([".venv/bin/python", "manage.py", "converge_pg_scheduler", *flag])
finally:
    cur.execute("SELECT pg_advisory_unlock(729891)")
    conn.close()
PY
echo "Migrations done; starting gunicorn"

exec .venv/bin/gunicorn \
  --bind "[::]:8000" \
  --workers "$GUNICORN_WORKERS" \
  --threads "$GUNICORN_THREADS" \
  --worker-class gthread \
  --log-level info \
  --timeout 600 \
  backend.wsgi:application
