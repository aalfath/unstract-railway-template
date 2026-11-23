"""Tiny /healthz server for the Railway health check of the workers service.

Answers 200 once every child's own liveness endpoint (upstream's /health on the
ports listed in $HEALTH_PORTS_FILE) answers 200, else 503. Listens on [::]:$PORT.
"""
import os
import socket
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORTS_FILE = os.environ.get("HEALTH_PORTS_FILE", "/tmp/unstract-health-ports")


def check() -> tuple[bool, str]:
    try:
        ports = [p.strip() for p in open(PORTS_FILE) if p.strip()]
    except OSError:
        ports = []
    if not ports:
        return False, "workers not started yet"
    bad = []
    for port in ports:
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=3)
        except Exception as e:  # noqa: BLE001
            bad.append(f"{port}:{e.__class__.__name__}")
    return (not bad), ("ok" if not bad else "unhealthy " + ",".join(bad))


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        if self.path.split("?")[0] not in ("/healthz", "/health"):
            self.send_response(404); self.end_headers(); return
        ok, msg = check()
        body = (msg + "\n").encode()
        self.send_response(200 if ok else 503)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class DualStack(ThreadingHTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


DualStack(("::", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
