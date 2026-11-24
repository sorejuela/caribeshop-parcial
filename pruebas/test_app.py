"""Comprueba comportamiento observable y que ningún secreto se devuelve al cliente."""

import json
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

from app import server


class AppTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.marker = Path(cls.temp.name) / "unhealthy"
        cls.patch = patch.object(server, "FAILURE_FILE", cls.marker)
        cls.patch.start()
        cls.http = ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.thread = threading.Thread(target=cls.http.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.http.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown()
        cls.http.server_close()
        cls.thread.join()
        cls.patch.stop()
        cls.temp.cleanup()

    def tearDown(self):
        self.marker.unlink(missing_ok=True)

    def get(self, path):
        try:
            response = urlopen(self.url + path, timeout=3)
        except HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    def test_health_and_unknown_route(self):
        self.assertEqual(self.get("/health")[0], 200)
        self.assertEqual(self.get("/admin/fail")[0], 404)

    def test_failure_and_recovery(self):
        self.marker.touch()
        self.assertEqual(self.get("/health")[0], 503)
        self.assertEqual(self.get("/work")[0], 503)
        self.marker.unlink()
        self.assertEqual(self.get("/health")[0], 200)

    def test_secret_response_only_contains_length(self):
        with patch.object(server, "secret_length", return_value=32):
            status, payload = self.get("/secret")
        self.assertEqual(status, 200)
        self.assertEqual(set(payload), {"secret_read", "length", "instance"})
        self.assertEqual(payload["length"], 32)

    def test_vault_failure_does_not_expose_error_details(self):
        with patch.object(server, "secret_length", side_effect=URLError("sensitive-token")):
            status, payload = self.get("/secret")
        self.assertEqual(status, 503)
        self.assertNotIn("sensitive-token", json.dumps(payload))


if __name__ == "__main__":
    unittest.main()
