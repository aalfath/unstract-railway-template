#!/bin/sh
# Waits for Postgres and makes sure the schema exists (upstream crashes on boot if the
# database or the schema isn't there yet, and the Backend may still be migrating).
set -eu
cd /app
.venv/bin/python - <<'PY'
import os, sys, time
import psycopg2
schema = os.environ.get("DB_SCHEMA", "unstract").replace('"', "")
for attempt in range(150):
    try:
        conn = psycopg2.connect(host=os.environ["DB_HOST"], port=os.environ.get("DB_PORT", "5432"),
            user=os.environ["DB_USERNAME"], password=os.environ["DB_PASSWORD"],
            dbname=os.environ["DB_NAME"], connect_timeout=5)
        conn.autocommit = True
        conn.cursor().execute(f'CREATE SCHEMA IF NOT EXISTS "{schema}"')
        conn.close()
        print(f"database ready (schema {schema})", flush=True)
        break
    except psycopg2.Error as e:
        if attempt % 10 == 0:
            print(f"waiting for Postgres ({e.__class__.__name__})", flush=True)
        time.sleep(2)
else:
    sys.exit("Postgres never became reachable")
PY
exec .venv/bin/gunicorn --bind '[::]:3004' --workers 1 --timeout 930 run:app
