#!/bin/sh
set -eu
cd /app
# Upstream's image hard-links llama_index's bundled nltk stopwords to the uv cache, and
# nltk's path guard refuses hard-linked files. Use a private copy (one link per file).
export NLTK_DATA="${NLTK_DATA:-/tmp/nltk_data}"
if [ ! -d "$NLTK_DATA/corpora" ]; then
  rm -r "$NLTK_DATA.tmp" 2>/dev/null || true
  cp -r /app/.venv/lib/python3.12/site-packages/llama_index/core/_static/nltk_cache "$NLTK_DATA.tmp"
  mv "$NLTK_DATA.tmp" "$NLTK_DATA"
fi
# Listen on [::] so Railway's IPv6 private network reaches it; one worker keeps it small.
exec .venv/bin/gunicorn --bind "[::]:3001" --workers 1 --threads 8 --worker-class gthread --timeout 300 unstract.platform_service.run:app
