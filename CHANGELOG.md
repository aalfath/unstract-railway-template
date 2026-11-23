# Changelog

## v0.204.0-1 (2026-11-23)

First release of the Railway template.

- Unstract v0.204.0. Images pinned by digest: `unstract/backend`, `unstract/frontend`, `unstract/platform-service`, `unstract/x2text-service`, `unstract/worker-unified`, `unstract/minio:RELEASE.2026-09-22T19-25-18Z` and `pgvector/pgvector:0.8.2-pg17`.
- Fix for upstream's images: llama_index's bundled nltk stopwords are hard-linked to the uv cache, and nltk's path guard refuses them, so every vector DB test and indexing run failed. The wrappers re-copy that folder.
- No RabbitMQ: the Celery transport stub uses Redis db 1. No runner, because it needs the Docker socket.
