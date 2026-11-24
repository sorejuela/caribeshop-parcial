"""Grafica P1 o resume errores de P2, exclusivamente desde CSV medidos."""

import argparse
import csv
import json
from datetime import datetime, timezone

parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest="mode", required=True)
plot = sub.add_parser("carga")
plot.add_argument("--history", required=True)
plot.add_argument("--instances", required=True)
plot.add_argument("--output", required=True)
failure = sub.add_parser("falla")
failure.add_argument("--requests", required=True)
failure.add_argument("--start", required=True, type=float, help="Epoch UTC de inyección efectiva")
failure.add_argument("--end", required=True, type=float, help="Epoch UTC del fin de la ventana")
failure.add_argument("--instance", help="Hostname X-Instance-ID de la instancia afectada")
args = parser.parse_args()


def rows(path):
    with open(path, newline="") as stream:
        return list(csv.DictReader(stream))


def utc(timestamp):
    return datetime.fromtimestamp(float(timestamp), timezone.utc)


if args.mode == "carga":
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.dates as mdates
    import matplotlib.pyplot as plt
    from matplotlib.ticker import MaxNLocator

    history = [r for r in rows(args.history) if r["Name"] == "Aggregated"]
    instances = rows(args.instances)
    if not history or not instances:
        parser.error("Los dos CSV deben contener mediciones.")
    fig, axes = plt.subplots(3, 1, sharex=True, figsize=(10, 7), layout="constrained")
    times = [utc(r["Timestamp"]) for r in history]
    axes[0].plot(times, [float(r["Requests/s"]) for r in history])
    axes[0].set_ylabel("RPS")
    # Locust escribe N/A antes de tener muestras; dejar un hueco, no inventar cero.
    p95 = [float(r["95%"]) if r["95%"] != "N/A" else float("nan") for r in history]
    axes[1].plot(times, p95, color="#ce6d28")
    axes[1].axhline(1000, color="#777777", linestyle="--", linewidth=1)
    axes[1].set_ylabel("p95 (ms)")
    axes[2].step([utc(r["timestamp"]) for r in instances],
                 [int(r["instances"]) for r in instances], where="post", label="Existentes")
    axes[2].step([utc(r["timestamp"]) for r in instances],
                 [int(r["capacity"]) for r in instances], where="post", linestyle="--", label="Configuradas")
    axes[2].set_ylabel("Instancias")
    axes[2].yaxis.set_major_locator(MaxNLocator(integer=True))
    axes[2].set_ylim(bottom=0, top=max(int(r["instances"]) for r in instances) + 1)
    axes[2].legend()
    axes[2].xaxis.set_major_formatter(mdates.DateFormatter("%H:%M", tz=timezone.utc))
    axes[2].set_xlabel("Hora UTC (p95 de la ventana reciente de Locust)")
    for ax in axes:
        ax.grid(alpha=0.2)
    fig.savefig(args.output, dpi=180)
else:
    if args.end <= args.start:
        parser.error("El fin debe ser posterior al inicio.")
    measured = [r for r in rows(args.requests) if args.start <= float(r["timestamp"]) <= args.end]
    if not measured:
        parser.error("No hay peticiones dentro de la ventana indicada.")
    errors = sum(int(r["failed"]) for r in measured)
    result = {"requests": len(measured), "errors": errors,
              "error_percent": round(100 * errors / len(measured), 3),
              "window_seconds": args.end - args.start}
    if args.instance:
        affected = [float(r["timestamp"]) for r in measured if r["instance"] == args.instance]
        result["last_affected_response_seconds"] = max(affected) - args.start if affected else None
    print(json.dumps(result, indent=2))
