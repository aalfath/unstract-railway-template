# Unstract workers (official unstract/worker-unified image). Upstream runs 12 worker
# containers; this service runs all of them as child processes of one supervisor
# script, sized for a small Railway service, and exits non-zero if any of them dies.
FROM unstract/worker-unified:v0.204.0@sha256:70143e636dda97a112f0da0f5fd5c4d4ab7f624291ec28b209c3b28ce41c338d
COPY --chmod=0755 start.sh /app/railway-start.sh
COPY --chmod=0755 health.py /app/railway-health.py
ENTRYPOINT []
CMD ["/app/railway-start.sh"]
