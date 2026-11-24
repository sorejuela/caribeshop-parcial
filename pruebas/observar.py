"""Muestrea instancias reales y capacidad configurada del VMSS en UTC."""

import argparse
import csv
import json
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--group", required=True)
parser.add_argument("--vmss", required=True)
parser.add_argument("--seconds", type=int, default=1860)
parser.add_argument("--output", required=True)
args = parser.parse_args()


def az(*command):
    return json.loads(subprocess.check_output(["az", *command, "-o", "json"], text=True))


end = time.monotonic() + args.seconds
with open(args.output, "w", newline="", buffering=1) as stream:
    writer = csv.writer(stream)
    writer.writerow(["timestamp", "instances", "capacity", "instance_ids", "zones", "healthy", "hostnames"])
    try:
        while time.monotonic() < end:
            instances = az("vmss", "list-instances", "-g", args.group, "-n", args.vmss,
                           "--expand", "instanceView")
            vmss = az("vmss", "show", "-g", args.group, "-n", args.vmss)
            writer.writerow([
                time.time(), len(instances), vmss["sku"]["capacity"],
                ";".join(str(vm["instanceId"]) for vm in instances),
                ";".join(",".join(vm.get("zones") or []) for vm in instances),
                sum(vm.get("instanceView", {}).get("vmHealth", {}).get("status", {}).get("code")
                    == "HealthState/healthy" for vm in instances),
                ";".join(vm.get("osProfile", {}).get("computerName", "") for vm in instances),
            ])
            time.sleep(15)
    except KeyboardInterrupt:
        pass
