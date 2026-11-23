# Unstract platform service (official image): adapter lookups and usage records for the workers.
FROM unstract/platform-service:v0.204.0@sha256:76b18f6ed14cda69035371fb4c53de691bbb9b972fb25ee07125191711ceb07c
ENV DB_SCHEMA=unstract \
    LOG_LEVEL=INFO \
    FLIPT_SERVICE_AVAILABLE=False \
    PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python \
    APPLICATION_NAME=unstract-platform-service
COPY --chmod=0755 start.sh /usr/local/bin/platform-start
CMD ["/usr/local/bin/platform-start"]
