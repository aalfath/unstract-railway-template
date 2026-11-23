# Unstract web app (official image) with a Railway-friendly nginx front:
# listens on $PORT and proxies the API paths to the Backend service over the private network.
FROM unstract/frontend:v0.204.0@sha256:e80f552f13548c731e46a4ad3a527f0f635ef797fb97c030faa1959148cf81fc
COPY --chown=nginx:nginx nginx.conf.template /etc/unstract/nginx.conf.template
COPY --chown=nginx:nginx start.sh /etc/unstract/start.sh
ENV UNSTRACT_APPS_VERSION=v0.204.0
USER nginx
ENTRYPOINT []
CMD ["/bin/sh", "/etc/unstract/start.sh"]
