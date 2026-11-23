# Unstract platform service (official image): adapter lookups and usage records for the workers.
FROM unstract/platform-service:v0.204.0@sha256:76b18f6ed14cda69035371fb4c53de691bbb9b972fb25ee07125191711ceb07c
# Upstream's image keeps uv's cache hard-linked into the venv; nltk's path guard then
# refuses llama_index's bundled stopwords ("refusing multiply-linked file") and every
# vector DB test/indexing fails. Re-copy that folder so each file has a single link.
USER root
RUN set -e; d=/app/.venv/lib/python3.12/site-packages/llama_index/core/_static/nltk_cache; \
    cp -a "$d" "$d.new" && rm -r "$d" && mv "$d.new" "$d" && \
    test -z "$(find "$d" -type f -links +1)"
USER unstract
ENV DB_SCHEMA=unstract \
    LOG_LEVEL=INFO \
    FLIPT_SERVICE_AVAILABLE=False \
    PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python \
    APPLICATION_NAME=unstract-platform-service
# Listen on [::] so Railway's IPv6 private network reaches it; 8 threads in one worker keep it small.
CMD [".venv/bin/gunicorn", "--bind", "[::]:3001", "--workers", "1", "--threads", "8", "--worker-class", "gthread", "--timeout", "300", "unstract.platform_service.run:app"]
