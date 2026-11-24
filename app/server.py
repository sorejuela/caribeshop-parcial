"""Aplicación mínima para probar salud, identidad administrada y carga CPU."""

import hashlib
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

INSTANCE = socket.gethostname()
FAILURE_FILE = Path(os.getenv("FAILURE_FILE", "/var/lib/caribeshop/unhealthy"))
WORK_ITERATIONS = int(os.getenv("WORK_ITERATIONS", "100000"))


def secret_length():
    """El token y el valor permanecen en memoria; nunca se imprimen."""
    token_request = Request(
        "http://169.254.169.254/metadata/identity/oauth2/token"
        "?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net",
        headers={"Metadata": "true"},
    )
    with urlopen(token_request, timeout=3) as response:
        token = json.load(response)["access_token"]
    vault_url = os.environ["KEY_VAULT_URL"].rstrip("/")
    secret_request = Request(
        f"{vault_url}/secrets/demo-token?api-version=7.4",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urlopen(secret_request, timeout=5) as response:
        return len(json.load(response)["value"])


class Handler(BaseHTTPRequestHandler):
    # HTTP/1.0 cierra conexiones: las pruebas observan nuevas decisiones del LB.
    def do_GET(self):
        path = urlsplit(self.path).path
        if path not in {"/", "/health", "/work", "/secret"}:
            return self.respond(404, {"error": "Ruta inexistente"})
        if FAILURE_FILE.exists():
            return self.respond(503, {"status": "unhealthy"})
        if path == "/secret":
            try:
                return self.respond(200, {"secret_read": True, "length": secret_length()})
            except (HTTPError, URLError, TimeoutError, KeyError, ValueError, OSError):
                return self.respond(503, {"error": "Key Vault no disponible"})
        if path == "/work":
            # Carga fija, sin parámetros controlados por el cliente. Libera el GIL.
            hashlib.pbkdf2_hmac("sha256", b"caribeshop", b"lab-workload", WORK_ITERATIONS)
        self.respond(200, {"status": "ok", "service": "CaribeShop"})

    def respond(self, status, payload):
        body = json.dumps({**payload, "instance": INSTANCE}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Instance-ID", INSTANCE)
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass  # El cliente puede abandonar una petición durante las fallas.

    def log_message(self, format, *args):
        pass  # No registrar encabezados, tokens, cuerpos ni cada petición de carga.


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(os.getenv("PORT", "8080"))), Handler).serve_forever()
