# Unstract workers (official unstract/worker-unified image). Upstream runs 12 worker
# containers; this service runs all of them as child processes of one supervisor
# script, sized for a small Railway service, and exits non-zero if any of them dies.
FROM unstract/worker-unified:v0.204.0@sha256:70143e636dda97a112f0da0f5fd5c4d4ab7f624291ec28b209c3b28ce41c338d
# Upstream's image hard-links llama_index's bundled nltk stopwords (uv cache); nltk's
# path guard then refuses them ("refusing multiply-linked file") and indexing fails.
# Re-copy that folder so each file has a single link.
USER root
RUN set -e; d=/app/.venv/lib/python3.12/site-packages/llama_index/core/_static/nltk_cache; \
    cp -a "$d" "$d.new" && rm -r "$d" && mv "$d.new" "$d" && \
    test -z "$(find "$d" -type f -links +1)"
USER worker
COPY --chmod=0755 start.sh /app/railway-start.sh
COPY --chmod=0755 health.py /app/railway-health.py
ENTRYPOINT []
CMD ["/app/railway-start.sh"]
