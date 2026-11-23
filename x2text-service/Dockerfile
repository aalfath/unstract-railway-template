# Unstract X2Text service (official image): bridge to an Unstructured.io server for the
# "Unstructured IO" text extractor. The start script waits for Postgres and creates the
# schema first, because upstream crashes on boot if either isn't there yet.
FROM unstract/x2text-service:v0.204.0@sha256:705e54e09db8c6290c3dec31edbff056856812659e86a9e68b5b6c3eae0f739b
ENV FLASK_ENV=production API_URL_PREFIX=/api/v1 DB_SCHEMA=unstract DB_PORT=5432
COPY --chmod=0755 start.sh /usr/local/bin/x2text-start
CMD ["/usr/local/bin/x2text-start"]
