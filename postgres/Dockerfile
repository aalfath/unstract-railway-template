# PostgreSQL 17 with the pgvector extension, so the bundled database can also be
# Unstract's vector store (the "Postgres" vector DB adapter, SSL on by default).
FROM pgvector/pgvector:0.8.2-pg17@sha256:feb68f4f15446397d8cac7f4fe48fe4586de83160d1fc48b46283312d1a33966
# Keep the data in a sub-folder of the Railway volume (the volume root has lost+found).
ENV PGDATA=/var/lib/postgresql/data/pgdata
COPY --chmod=0755 start.sh /usr/local/bin/railway-postgres-start
ENTRYPOINT ["/usr/local/bin/railway-postgres-start"]
