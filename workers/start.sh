#!/bin/bash
# Railway start script for the Unstract workers (unstract/worker-unified:v0.204.0).
# Runs every process upstream's docker-compose.yaml runs as a separate container
# (11 PG-queue consumers / reaper / log consumers), each with the same per-container
# environment, plus a small /healthz server on $PORT. If any child exits, the rest
# are stopped and the service exits 1 so Railway's restart policy brings it back.
set -uo pipefail
cd /app

export DB_SCHEMA="${DB_SCHEMA:-unstract}" DB_PORT="${DB_PORT:-5432}"
export REDIS_PORT="${REDIS_PORT:-6379}" REDIS_USER="${REDIS_USER:-default}" REDIS_DB=0
export CACHE_REDIS_ENABLED=true CACHE_REDIS_HOST="$REDIS_HOST" CACHE_REDIS_PORT="$REDIS_PORT" \
       CACHE_REDIS_DB=0 CACHE_REDIS_USERNAME="$REDIS_USER" CACHE_REDIS_PASSWORD="${REDIS_PASSWORD:-}"
export CELERY_BACKEND_DB_SCHEMA=public
export CELERY_BROKER_BASE_URL="${CELERY_BROKER_BASE_URL:-redis://${REDIS_HOST}:${REDIS_PORT}/1}"
export CELERY_BROKER_USER="${CELERY_BROKER_USER:-$REDIS_USER}" CELERY_BROKER_PASS="${CELERY_BROKER_PASS:-${REDIS_PASSWORD:-}}"
export LOG_TRANSPORT=redis ENABLE_LOG_HISTORY=true LOG_HISTORY_QUEUE_NAME=log_history_queue
export FLIPT_SERVICE_AVAILABLE=False PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
export ENVIRONMENT=production LOG_LEVEL="${LOG_LEVEL:-INFO}" DEFAULT_LOG_LEVEL="${LOG_LEVEL:-INFO}"
export DJANGO_APP_BACKEND_URL="${DJANGO_APP_BACKEND_URL:-http://${BACKEND_HOST:?BACKEND_HOST is not set}:8000}"
export INTERNAL_API_BASE_URL="${INTERNAL_API_BASE_URL:-${DJANGO_APP_BACKEND_URL}/internal}"
export PLATFORM_SERVICE_HOST="${PLATFORM_SERVICE_HOST:-http://${PLATFORM_HOST:?PLATFORM_HOST is not set}}" PLATFORM_SERVICE_PORT="${PLATFORM_SERVICE_PORT:-3001}"
export X2TEXT_HOST="${X2TEXT_HOST:-http://${X2TEXT_HOSTNAME:?X2TEXT_HOSTNAME is not set}}" X2TEXT_PORT="${X2TEXT_PORT:-3004}"
export TOOL_REGISTRY_CONFIG_PATH=/unstract/tool-registry/tool_registry_config TOOL_REGISTRY_STORAGE_CREDENTIALS='{"provider":"local"}'
export REMOTE_PROMPT_STUDIO_FILE_PATH=unstract/prompt-studio-data
export WORKFLOW_EXECUTION_DIR_PREFIX=unstract/execution API_EXECUTION_DIR_PREFIX=unstract/api AGENT_KV_STORAGE_DIR_PREFIX=unstract/agent_kv
export EXECUTOR_RESULT_TIMEOUT=3600 EXECUTOR_TASK_TIME_LIMIT=3600
storage_json=$(.venv/bin/python -c 'import json,os;print(json.dumps({"provider":"minio","credentials":{"endpoint_url":os.environ["MINIO_ENDPOINT"],"key":os.environ["MINIO_ACCESS_KEY"],"secret":os.environ["MINIO_SECRET_KEY"]}}))')
for v in WORKFLOW_EXECUTION_FILE_STORAGE_CREDENTIALS API_FILE_STORAGE_CREDENTIALS PERMANENT_REMOTE_STORAGE TEMPORARY_REMOTE_STORAGE HITL_FILES_FILE_STORAGE_CREDENTIALS AGENT_KV_FILE_STORAGE_CREDENTIALS; do
  export "$v=$storage_json"
done
for v in DB_HOST DB_USER DB_PASSWORD DB_NAME REDIS_HOST INTERNAL_SERVICE_API_KEY MINIO_ENDPOINT; do
  if [ -z "${!v:-}" ]; then echo "Missing required variable $v" >&2; exit 1; fi
done

# Health server first, so Railway sees "starting" rather than a dead port.
export HEALTH_PORTS_FILE=/tmp/unstract-health-ports
: > "$HEALTH_PORTS_FILE"
/app/.venv/bin/python /app/railway-health.py &
health_pid=$!

# The PG queue tables come from the backend's migrations: wait for the backend.
/app/.venv/bin/python - <<'PY' || exit 1
import os, time, urllib.request
url = os.environ["DJANGO_APP_BACKEND_URL"].rstrip("/") + "/health"
for attempt in range(600):
    try:
        urllib.request.urlopen(url, timeout=5); print(f"backend is up ({url})", flush=True); break
    except Exception as e:
        if attempt % 15 == 0: print(f"waiting for the backend at {url} ({e.__class__.__name__})", flush=True)
        time.sleep(2)
else:
    raise SystemExit("backend never became healthy")
PY

pids=()
start() {  # start NAME [VAR=value ...] -- COMMAND...
  local name=$1; shift; local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  echo "starting $name"
  env APPLICATION_NAME="unstract-$name" "${envs[@]}" "$@" &
  pids+=("$!")
}
pg() {  # pg NAME WORKER_TYPE QUEUES HEALTH_PORT VT STALE CONCURRENCY [VAR=value ...]
  local name=$1 type=$2 queues=$3 port=$4 vt=$5 stale=$6 conc=$7; shift 7
  echo "$port" >> "$HEALTH_PORTS_FILE"
  start "$name" WORKER_BARRIER_BACKEND=pg WORKER_PG_QUEUE_CONSUMER_WORKER_TYPE="$type" \
    WORKER_PG_QUEUE_CONSUMER_QUEUE="$queues" WORKER_PG_QUEUE_CONSUMER_HEALTH_PORT="$port" \
    WORKER_PG_QUEUE_CONSUMER_VT_SECONDS="$vt" WORKER_PG_QUEUE_CONSUMER_HEALTH_STALE_SECONDS="$stale" \
    WORKER_PG_QUEUE_CONSUMER_CONCURRENCY="$conc" "$@" -- /app/run-worker-docker.sh pg-queue-consumer
}

# Same queues, timeouts and health bounds as upstream docker-compose.yaml (v0.204.0).
# Concurrency is lower than upstream's defaults to fit a small service; raise
# PG_EXECUTOR_CONCURRENCY / PG_FILEPROC_CONCURRENCY on a bigger plan.
pg worker-pg-executor executor \
  celery_executor_legacy,celery_executor_agentic,celery_executor_table,celery_executor_smart_table,celery_executor_simple_prompt_studio,celery_executor_agentic_table,celery_executor_lookup_test \
  8099 3660 3720 "${PG_EXECUTOR_CONCURRENCY:-1}" \
  CELERY_QUEUES_EXECUTOR=celery_executor_legacy,celery_executor_agentic,celery_executor_agentic_table
pg worker-pg-orchestrator-api api_deployment celery_api_deployments 8093 600 660 1
pg worker-pg-orchestrator-general general celery 8094 600 660 1
pg worker-pg-fileproc file_processing file_processing,file_processing_priority,api_file_processing 8095 3660 3720 "${PG_FILEPROC_CONCURRENCY:-1}"
pg worker-pg-callback callback file_processing_callback,celery_callback,api_file_processing_callback 8096 3660 3720 1
pg worker-pg-scheduler scheduler scheduler 8098 180 240 1
pg worker-pg-metrics scheduler dashboard_metric_events 8101 900 960 1 WORKER_PG_QUEUE_CONSUMER_MAX_ATTEMPTS=1
pg worker-pg-ide-callback ide_callback ide_callback,agent_kv_callback 8100 120 180 1
pg worker-pg-notification notification notifications,notifications_webhook,notifications_email,notifications_sms,notifications_priority 8104 300 360 1
echo 8097 >> "$HEALTH_PORTS_FILE"
start worker-pg-reaper WORKER_PG_REAPER_INTERVAL_SECONDS=5 WORKER_PG_REAPER_HEALTH_PORT=8097 \
  WORKER_PG_REAPER_SWEEP_SECONDS=300 WORKER_PG_DEDUP_RETENTION_SECONDS=86400 -- /app/run-worker-docker.sh pg-queue-reaper
start worker-log-stream-consumer WORKER_TYPE=log_consumer WORKER_NAME=log-stream-consumer \
  LOG_STREAM_QUEUE_NAME=log_stream_queue -- /app/run-worker-docker.sh log-stream-consumer
start worker-log-history-scheduler LOG_HISTORY_CONSUMER_INTERVAL=5 -- /bin/bash /app/log_consumer/scheduler.sh

stop_all() { kill "${pids[@]}" "$health_pid" 2>/dev/null; wait 2>/dev/null; }
trap 'echo "stopping workers"; stop_all; exit 0' TERM INT
wait -n "${pids[@]}" "$health_pid"
code=$?
echo "a worker process exited (code $code); stopping the others so Railway restarts the service" >&2
stop_all
exit 1
