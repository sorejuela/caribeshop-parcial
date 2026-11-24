"""P1: PERFIL=escalonado; capacidad y P2: opciones habituales -u, -r, -t."""

import csv
import os
import time
from pathlib import Path

from locust import HttpUser, LoadTestShape, between, events, task

request_file = None
request_writer = None


@events.test_start.add_listener
def open_request_log(environment, **kwargs):
    global request_file, request_writer
    path = os.getenv("REQUEST_LOG")
    if path:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        request_file = open(path, "w", newline="", buffering=1)
        request_writer = csv.writer(request_file)
        request_writer.writerow(["timestamp", "instance", "status", "failed", "response_ms"])


@events.request.add_listener
def record_request(response=None, exception=None, response_time=0, **kwargs):
    if request_writer is not None:
        request_writer.writerow([
            time.time(),
            response.headers.get("X-Instance-ID", "") if response is not None else "",
            response.status_code if response is not None else 0,
            int(exception is not None),
            round(response_time, 2),
        ])


@events.test_stop.add_listener
def close_request_log(environment, **kwargs):
    global request_file, request_writer
    if request_file:
        request_file.close()
    request_file = request_writer = None


class Shopper(HttpUser):
    wait_time = between(0.05, 0.15)

    @task
    def work(self):
        self.client.get("/work", timeout=5)


if os.getenv("PERFIL") == "escalonado":
    class SteppedLoad(LoadTestShape):
        # 30 minutos: subida, 11 min sostenidos y 12 min de bajada/recuperación.
        peak = int(os.getenv("PEAK_USERS", "100"))
        stages = [(180, 0.1), (420, 0.5), (1080, 1.0), (1260, 0.25), (1800, 0.02)]

        def tick(self):
            for duration, fraction in self.stages:
                if self.get_run_time() < duration:
                    return max(1, int(self.peak * fraction)), max(1, self.peak / 20)
            return None
