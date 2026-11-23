# MinIO object storage for uploaded and processed files (Unstract's own MinIO mirror,
# same pin as upstream docker-compose-dev-essentials.yaml at v0.204.0).
FROM unstract/minio:RELEASE.2026-09-22T19-25-18Z@sha256:bd014394a80898e68c149f2311fdf8d5a2c2f3bb2c33b9327ae6d02b4b065ae1
# Railway volumes are owned by root.
USER 0
ENV MINIO_BROWSER=off
ENTRYPOINT ["/usr/bin/minio"]
CMD ["server", "/data", "--address", ":9000"]
