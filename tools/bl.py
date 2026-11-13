#!/usr/bin/env python3
"""Run Python in the open Blender through the Blender Lab MCP add-on socket.

Usage: tools/bl.py 'result = {...}'   or   tools/bl.py < script.py
Assign a JSON-serialisable dict to `result` to get data back.
"""
import json, os, socket, sys

code = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()
host = os.environ.get("BLENDER_MCP_HOST", "localhost")
port = int(os.environ.get("BLENDER_MCP_PORT", "9876"))
with socket.create_connection((host, port), timeout=300) as s:
    s.sendall((json.dumps({"type": "execute", "code": code, "strict_json": False}) + "\0").encode())
    buf = bytearray()
    while b"\0" not in buf:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf.extend(chunk)
resp = json.loads(buf.partition(b"\0")[0].decode())
print(json.dumps(resp, indent=1))
sys.exit(0 if resp.get("status") == "ok" else 1)
