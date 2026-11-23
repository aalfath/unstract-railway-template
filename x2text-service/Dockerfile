# Unstract X2Text service (official image): bridge to an Unstructured.io server for the
# "Unstructured IO" text extractor. Waits for Postgres, because upstream crashes if the
# database is not up yet.
FROM unstract/x2text-service:v0.204.0@sha256:705e54e09db8c6290c3dec31edbff056856812659e86a9e68b5b6c3eae0f739b
ENV FLASK_ENV=production API_URL_PREFIX=/api/v1 DB_SCHEMA=unstract DB_PORT=5432
CMD ["sh", "-c", "until .venv/bin/python -c 'import os,socket;socket.create_connection((os.environ[\"DB_HOST\"],int(os.environ.get(\"DB_PORT\",\"5432\"))),3)' 2>/dev/null; do echo waiting for Postgres; sleep 2; done; exec .venv/bin/gunicorn --bind '[::]:3004' --workers 1 --timeout 930 run:app"]
