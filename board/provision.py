#!/usr/bin/env python3
"""Write a board's config (WiFi, server endpoint and token, antenna) over USB serial.

Replaces everything stored on the board. Usage:
    ~/.platformio/penv/bin/python provision.py provision/<place>.json [port]
"""
import json
import sys
import time

import serial  # pyserial, bundled with PlatformIO
from serial.tools import list_ports

if len(sys.argv) < 2:
    sys.exit(__doc__)

with open(sys.argv[1]) as f:
    line = b"PROVISION " + json.dumps(json.load(f)).encode() + b"\n"

ports = [p.device for p in list_ports.comports()]
if len(sys.argv) > 2:
    port = sys.argv[2]
elif len(ports) == 1:
    port = ports[0]
else:
    sys.exit(f"Pass the serial port explicitly, found: {ports}")

deadline = time.time() + 30
with serial.Serial(port, 115200, timeout=0.5) as board:
    # A provisioned board only listens for 3 s after boot, so reset it and keep resending
    print(f"Sending {sys.argv[1]} to {port}. Press the board's reset button if nothing happens.")
    while time.time() < deadline:
        board.write(line)
        reply = board.readline().decode(errors="replace").strip()
        if reply.startswith("PROVISION_ERROR"):
            sys.exit(reply)
        if reply.startswith("PROVISIONED"):
            print(reply)
            sys.exit(0)
sys.exit("Timed out waiting for the board to accept the config")
