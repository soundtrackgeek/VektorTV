#!/usr/bin/env python3
"""Check Apple's OS calls bind to libSystem, not VLCKit's legacy libc shims."""
from pathlib import Path
import plistlib
import subprocess
import sys

app = Path(sys.argv[1])
with (app / "Info.plist").open("rb") as file:
    executable = plistlib.load(file)["CFBundleExecutable"]
binary = app / executable
debug = app / (executable + ".debug.dylib")
if debug.exists():
    binary = debug
imports = subprocess.check_output(["xcrun", "dyld_info", "-imports", str(binary)], text=True)
clocks = [line for line in imports.splitlines() if "_clock_gettime " in line]
if not clocks or any("(from libSystem)" not in line for line in clocks):
    raise SystemExit("Playback linkage failed: clock_gettime must bind to Apple's libSystem. Link -lSystem before VLCKit.")
print("Playback linkage passed: clock_gettime binds to libSystem.")
