#!/usr/bin/env python3
"""handshake.py — stdio smoke test for an MCP server.

Spawns the server, performs the 2025-11-25 initialize handshake, sends
notifications/initialized, then calls tools/list. Verifies:

  - every message is one newline-delimited JSON object (stdio framing —
    no embedded newlines, stdout carries MCP only)
  - the server answers initialize with protocolVersion 2025-11-25
  - tools/list returns a list
  - teardown is bounded: stdin EOF -> wait -> SIGTERM -> (fail) SIGKILL;
    a server that survives EOF+SIGTERM is a zombie risk

Usage: handshake.py <server-cmd> [args...]
Exit 0 on success, 1 on any failure. Prints a short report.
"""

import json
import selectors
import subprocess
import sys

PROTOCOL_VERSION = "2025-11-25"
READ_TIMEOUT = 10


def main(argv):
    if not argv:
        print("usage: handshake.py <server-cmd> [args...]", file=sys.stderr)
        return 2

    proc = subprocess.Popen(
        argv,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    sel = selectors.DefaultSelector()
    sel.register(proc.stdout, selectors.EVENT_READ)
    failures = []

    def rpc(obj):
        line = json.dumps(obj, separators=(",", ":"))
        if "\n" in line:
            failures.append("outbound message contains an embedded newline")
        proc.stdin.write(line + "\n")
        proc.stdin.flush()

    def read_msg(what):
        if not sel.select(READ_TIMEOUT):
            failures.append(f"timed out ({READ_TIMEOUT}s) waiting for {what}")
            return None
        line = proc.stdout.readline()
        if not line:
            failures.append(f"EOF on stdout waiting for {what}")
            return None
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            failures.append(
                f"non-JSON on stdout waiting for {what}: {line[:120]!r} "
                "(stdout is MCP-only; logs belong on stderr)"
            )
            return None

    # 1. initialize
    rpc(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {},
                "clientInfo": {"name": "handshake-smoke", "version": "0.1.0"},
            },
        }
    )
    resp = read_msg("initialize response")
    if resp is not None:
        pv = (resp.get("result") or {}).get("protocolVersion")
        if pv != PROTOCOL_VERSION:
            failures.append(f"protocolVersion {pv!r} != {PROTOCOL_VERSION!r}")
        else:
            print(f"ok: initialize negotiated {pv}")

    # 2. initialized notification (no response expected)
    rpc({"jsonrpc": "2.0", "method": "notifications/initialized"})

    # 3. tools/list
    rpc({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
    resp = read_msg("tools/list response")
    if resp is not None:
        tools = (resp.get("result") or {}).get("tools")
        if isinstance(tools, list):
            print(f"ok: tools/list returned {len(tools)} tool(s)")
            for t in tools:
                print(f"     - {t.get('name', '<unnamed>')}")
        else:
            failures.append("tools/list result.tools is not a list")

    # 4. bounded teardown: EOF -> wait -> SIGTERM -> SIGKILL
    sel.unregister(proc.stdout)
    proc.stdin.close()
    try:
        proc.wait(timeout=5)
        print("ok: server exited on stdin EOF")
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=5)
            print("ok: server exited on SIGTERM")
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            failures.append(
                "server survived stdin EOF + SIGTERM (zombie risk — "
                "fix teardown before shipping)"
            )
    # process has exited (or been killed) above, so this read cannot block
    stderr = proc.stderr.read()
    if proc.returncode not in (0, None):
        print(f"note: server exit code {proc.returncode}")
    if stderr.strip():
        print(
            f"note: server wrote {len(stderr)} chars to stderr "
            "(correct channel for logs)"
        )

    if failures:
        print("FAILURES:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print("HANDSHAKE OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
