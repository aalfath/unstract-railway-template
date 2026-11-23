# Unstract Django backend (official image). The start script creates the DB schema,
# the pgvector extension and the MinIO bucket, takes a lock so overlapping deploys
# never migrate at once, runs the migrations, then starts gunicorn on [::]:8000.
FROM unstract/backend:v0.204.0@sha256:fe4152dd4d2dffcf421ef090e0730a9440a3876bc722828b9d83aad48c0698d8
COPY --chmod=0755 start.sh /usr/local/bin/unstract-backend-start
ENTRYPOINT []
CMD ["/usr/local/bin/unstract-backend-start"]
