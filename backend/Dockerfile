# Unstract Django backend (official image). The start script creates the DB schema,
# the pgvector extension and the MinIO bucket, takes a lock so overlapping deploys
# never migrate twice, then runs upstream's entrypoint with --migrate.
FROM unstract/backend:v0.204.0@sha256:fe4152dd4d2dffcf421ef090e0730a9440a3876bc722828b9d83aad48c0698d8
# Upstream's image keeps uv's cache hard-linked into the venv; nltk's path guard then
# refuses llama_index's bundled stopwords ("refusing multiply-linked file") and every
# vector DB test/indexing fails. Re-copy that folder so each file has a single link.
RUN set -e; d=/app/.venv/lib/python3.12/site-packages/llama_index/core/_static/nltk_cache; \
    cp -a "$d" "$d.new" && rm -r "$d" && mv "$d.new" "$d" && \
    test -z "$(find "$d" -type f -links +1)"
COPY --chmod=0755 start.sh /usr/local/bin/unstract-backend-start
ENTRYPOINT []
CMD ["/usr/local/bin/unstract-backend-start"]
