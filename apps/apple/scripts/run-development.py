#!/usr/bin/env python3
"""Explicit simulator-only account injection. Never embeds secrets in a bundle."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
path = root / ".env"
if not path.exists():
    path = root / "env"
values = {}
for line in path.read_text().splitlines():
    if not line.strip() or line.lstrip().startswith("#") or "=" not in line:
        continue
    name, value = line.split("=", 1)
    values[name.strip()] = value.strip().strip("\"'")
if not values.get("iptv_username") or not values.get("iptv_password"):
    raise SystemExit("Set iptv_username and iptv_password in the ignored .env file.")
device = sys.argv[1] if len(sys.argv) > 1 else "booted"
env = os.environ.copy()
env.update(SIMCTL_CHILD_IPTV_USERNAME=values["iptv_username"], SIMCTL_CHILD_IPTV_PASSWORD=values["iptv_password"], SIMCTL_CHILD_IPTV_URL=values.get("iptv_url", "http://ourxtream.com"))
subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device, "com.soundtrackgeek.vektortv", "--use-development-account"], env=env, check=True)
