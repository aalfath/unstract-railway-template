[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/unstract?utm_medium=integration&utm_source=button&utm_campaign=unstract)

# Unstract on Railway

One-click Railway template for [Unstract](https://github.com/Zipstack/unstract) **v0.204.0**, the open-source (AGPL-3.0) no-code LLM platform that turns unstructured documents (PDFs, scans, Office files) into structured JSON, served as APIs or ETL pipelines.

Every service builds from this repository, and each Dockerfile pins an official Unstract image by version and digest. When this repo's `main` branch moves to a new Unstract version, Railway shows you an "update available" notice in your project. See [`CHANGELOG.md`](CHANGELOG.md) before you apply it.

## What gets deployed

| Service | Folder | What it does |
|---|---|---|
| **Unstract** (public) | `frontend/` | Web app (nginx) on `$PORT`; proxies `/api/v1`, `/deployment` and `/public` to the Backend over the private network. Health check `/healthz`. |
| Backend | `backend/` | Django API. First boot creates the schema, the pgvector extension and the MinIO bucket, then runs migrations under a Postgres lock. Health check `/health`. |
| Workers | `workers/` | Upstream's 9 Postgres-queue consumers, the queue reaper and the log consumers (`unstract/worker-unified`) in one service; exits non-zero if any of them dies, so Railway restarts it. Health check `/healthz`. |
| Platform Service | `platform-service/` | Adapter and usage lookups for the workers. Health check `/health`. |
| X2Text Service | `x2text-service/` | Bridge to an Unstructured.io server for the "Unstructured IO Community" text extractor. Waits for Postgres and creates the schema before it starts. Health check `/api/v1/x2text/health`. |
| Postgres | `postgres/` | PostgreSQL 17 + pgvector (`pgvector/pgvector:0.8.2-pg17`), with SSL on. It is Unstract's database **and** can be its vector DB. Volume at `/var/lib/postgresql/data`. |
| MinIO | `minio/` | Object storage for uploaded and processed files (Unstract's own MinIO build). Volume at `/data`. |
| Redis | Railway Redis | Cache, log stream and Celery transport stub. |

Left out on purpose:

- **RabbitMQ.** In v0.204.0 all dispatch runs through Postgres queues, and the Celery transport stub points at Redis.
- **Runner and tool sidecar.** They need the Docker socket (Docker-in-Docker), which Railway doesn't offer. Prompt Studio, API deployments and ETL pipelines work without them, because the executor workers run the structure tool in-process.
- **Qdrant.** The bundled Postgres with pgvector serves as the vector DB.
- **Traefik, Flipt and the Unstructured API.** Traefik is replaced by the nginx front, Flipt (feature flags) is optional, and the Unstructured API is an optional extractor you can host yourself.

## Variables

You get no prompts at deploy time: every password and key is generated. LLM keys are entered in the web app, not as Railway variables.

| Variable | Service | Value |
|---|---|---|
| `DEFAULT_AUTH_USERNAME` | Backend | `unstract`: the login name for the web app |
| `DEFAULT_AUTH_PASSWORD` | Backend | `${{secret(24)}}`: the login password (shown in the Backend's Variables tab) |
| `DJANGO_SECRET_KEY`, `SYSTEM_ADMIN_PASSWORD` | Backend | generated |
| `ENCRYPTION_KEY` | Backend, Platform Service | generated Fernet key that encrypts the saved adapter credentials. **Never change it after first use**, or the saved adapters can no longer be read. |
| `INTERNAL_SERVICE_API_KEY` | Backend, Workers | generated; workers use it to call the Backend |
| `POSTGRES_PASSWORD`, `MINIO_ROOT_PASSWORD` | Postgres, MinIO | generated; the other services read them through reference variables |

## After deploy

1. Open the **Unstract** service's public URL. Log in as `unstract`, with the password from **Backend → Variables → `DEFAULT_AUTH_PASSWORD`**.
2. Under **Settings → LLMs / Embeddings / Vector DBs / Text Extractors**, add:
   - **LLM:** OpenAI, Anthropic, Azure, Bedrock, Gemini, Ollama or any "OpenAI Compatible" endpoint, with your own API key.
   - **Embedding:** for example OpenAI `text-embedding-3-small`.
   - **Vector DB:** "Postgres", with host `postgres.railway.internal`, port `5432`, database `unstract`, user `unstract`, the password from **Postgres → Variables → `POSTGRES_PASSWORD`**, and SSL on.
   - **Text Extractor:** LLMWhisperer (free tier key) or LlamaParse, or the "Unstructured IO Community" extractor pointed at your own Unstructured API server.
3. Create a Prompt Studio project, upload a document, write prompts, then deploy it as an API or an ETL pipeline.

## Resources

Measured on Railway with a real Prompt Studio run (upload, indexing, prompt), as memory in use:

| Service | RAM |
|---|---|
| Workers | about 1.6 GB (12 Python processes); give it **2 GB** |
| Backend | about 0.6 GB under load, and it is OOM-killed at 0.5 GB; give it **1 GB** |
| Platform, X2Text, Postgres, MinIO, Redis, Unstract | under 0.1 GB each |

That is about 2.5 GB in total. It doesn't fit Railway's Free or Trial plan (0.5 GB per service, and too few services), so use the **Hobby** plan or higher. Every worker runs with concurrency 1; raise `PG_EXECUTOR_CONCURRENCY` and `PG_FILEPROC_CONCURRENCY` on Workers for more parallel documents (each extra slot costs RAM).

## Updating

Bump the `FROM` lines in every folder to the same new Unstract tag and digest, add a `CHANGELOG.md` entry, and merge to `main`. Deployers get Railway's update notice and choose when to apply it. Migrations run automatically on the Backend's next start.

## Local test

`compose.local.yaml` runs the same stack with Docker Compose (test passwords only, for local use).

## Licence

Unstract is AGPL-3.0 (Zipstack Inc.). The wrapper files in this repo are MIT.
