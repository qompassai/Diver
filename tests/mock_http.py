"""Loopback-only protocol fixtures. No vendor credentials or real agents are contacted."""
from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import threading
import time
import uuid

import jsonschema
import yaml
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TASKS: dict[str, dict] = {}
RUNS: dict[str, dict] = {}
REQUESTS: list[dict] = []
FAILURES: list[str] = []
BASE = ""
SPEC_ROOT = pathlib.Path(__file__).resolve().parent / "spec"
OLD_SCHEMA = json.loads((SPEC_ROOT / "a2a-v03.json").read_text())
ACP_SCHEMA = yaml.safe_load((SPEC_ROOT / "communication.yaml").read_text())
SCHEMA_CHECKS = 0


def validate(value, name, communication=False):
    global SCHEMA_CHECKS
    if communication:
        schema = dict(ACP_SCHEMA, **{"$ref": "#/components/schemas/" + name})
        jsonschema.Draft202012Validator(schema).validate(value)
    else:
        schema = dict(OLD_SCHEMA, **{"$ref": "#/definitions/" + name})
        jsonschema.Draft7Validator(schema).validate(value)
    SCHEMA_CHECKS += 1


def message(text, version="1.0", context="ctx-fixture"):
    value = {"messageId": str(uuid.uuid4()), "role": "ROLE_AGENT", "contextId": context,
             "parts": [{"text": text}]}
    if version == "0.3":
        value.update(kind="message", role="agent")
        value["parts"][0]["kind"] = "text"
    return value


def task(identifier, state="WORKING", version="1.0"):
    value = {"id": identifier, "contextId": "ctx-" + identifier,
             "status": {"state": "TASK_STATE_" + state}, "artifacts": [], "history": []}
    if version == "0.3":
        value["kind"] = "task"
        value["status"]["state"] = state.lower().replace("_", "-")
    return value


def manifest():
    return {"name": "writer", "description": "Fixture writer", "input_content_types": ["text/plain"],
            "output_content_types": ["text/plain"]}


def run(status="in-progress", identifier=None):
    return {"agent_name": "writer", "run_id": identifier or str(uuid.uuid4()), "status": status,
            "session_id": "33333333-3333-4333-a333-333333333333", "output": [],
            "created_at": "2026-09-23T00:00:00Z"}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass

    def json_reply(self, value, status=200):
        data = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def sse(self, values, truncated=False):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        self.wfile.write(b": heartbeat\r\n\r\n")
        for value in values:
            data = ("data: " + json.dumps(value, ensure_ascii=False) + "\r\n\r\n").encode()
            for offset in range(0, len(data), 11):
                self.wfile.write(data[offset:offset + 11])
                self.wfile.flush()
        if truncated:
            self.wfile.write(b'data: {"unfinished":')

    def do_GET(self):
        if self.path.endswith("/card"):
            peer = self.path.split("/")[1]
            version = "0.3" if peer == "old" else "1.0"
            card = {"name": peer, "description": "Test agent", "version": "1.0.0",
                    "capabilities": {"streaming": True, "extendedAgentCard": True},
                    "defaultInputModes": ["text/plain"], "defaultOutputModes": ["text/plain"],
                    "skills": [{"id": "review", "name": "Review", "description": "Review text",
                                "tags": ["review"]}]}
            endpoint = BASE + "/" + peer + "/rpc"
            if version == "0.3":
                card.update(protocolVersion="0.3.0", url=endpoint, preferredTransport="JSONRPC")
            else:
                card["supportedInterfaces"] = [{"url": endpoint, "protocolBinding": "JSONRPC",
                                                 "protocolVersion": "1.0", "tenant": peer}]
            if peer == "evil":
                card["supportedInterfaces"][0]["url"] = "https://unapproved.invalid/rpc"
            if version == "0.3":
                validate(card, "AgentCard")
            self.json_reply(card)
        elif self.path == "/legacy/agents/writer":
            self.json_reply(manifest())
        elif self.path == "/legacy/agents":
            self.json_reply({"agents": [manifest()]})
        elif self.path.startswith("/legacy/runs/"):
            identifier = self.path.split("/")[3]
            if self.path.endswith("/events"):
                self.json_reply({"events": [{"type": "run.completed", "run": RUNS[identifier]}]})
                return
            value = RUNS[identifier]
            if value["status"] == "in-progress":
                value["status"] = "completed"
                value["output"] = [{"role": "agent/writer", "parts": [
                    {"content_type": "text/plain", "content": "Legacy result"}]}]
            self.json_reply(value)
        elif self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", BASE + "/trap")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif self.path == "/trap":
            FAILURES.append("Redirect followed")
            self.json_reply({"bad": True})
        elif self.path == "/large":
            self.json_reply({"data": "x" * (8 * 1024 * 1024 + 1)})
        else:
            self.json_reply({"error": "missing"}, 404)

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            assert length < 2 * 1024 * 1024
            data = self.rfile.read(length)
            body = json.loads(data) if data else {}
            if self.path.startswith("/legacy/"):
                self.legacy(body)
            else:
                self.a2a(body)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as exc:
            FAILURES.append(str(exc))
            self.json_reply({"fixture_error": str(exc)}, 400)

    def legacy(self, body):
        REQUESTS.append({"path": self.path, "body": body})
        if self.path.endswith("/cancel"):
            value = RUNS[self.path.split("/")[3]]
            value["status"] = "cancelled"
            self.json_reply(value, 202)
            return
        assert body["mode"] in ("async", "stream", "sync")
        validate(body, "RunCreateRequest" if self.path == "/legacy/runs" else "RunResumeRequest", True)
        if self.path == "/legacy/runs":
            assert body["agent_name"] == "writer" and body["input"][0]["role"] == "user"
            text = body["input"][0]["parts"][0]["content"]
            value = run("awaiting" if text == "await" else "in-progress")
            if text == "await":
                value["await_request"] = {"question": "Continue?"}
        else:
            value = RUNS[self.path.split("/")[3]]
            assert body["run_id"] == value["run_id"] and body["await_resume"] == {"answer": "yes"}
            value["status"] = "completed"
            value.pop("await_request", None)
        validate(value, "Run", True)
        RUNS[value["run_id"]] = value
        if body["mode"] == "stream":
            start = dict(value)
            value["status"] = "completed"
            value["output"] = [{"role": "agent", "parts": [
                {"content_type": "text/plain", "content": "Stream legacy"}]}]
            self.sse([{"type": "run.created", "run": start},
                      {"type": "message.part", "part": {"content_type": "text/plain", "content": "Stream"}},
                      {"type": "run.completed", "run": value}])
        else:
            self.json_reply(value, 202)

    def a2a(self, body):
        peer = self.path.split("/")[1]
        version = "0.3" if peer == "old" else "1.0"
        assert body["jsonrpc"] == "2.0" and body["id"]
        assert self.headers.get("A2A-Version") == version
        params, method = body.get("params", {}), body["method"]
        if version == "0.3":
            schema_names = {"message/send": "SendMessageRequest", "message/stream": "SendStreamingMessageRequest",
                            "tasks/get": "GetTaskRequest", "tasks/cancel": "CancelTaskRequest"}
            if method in schema_names:
                validate(body, schema_names[method])
        if version == "1.0":
            assert params.get("tenant") == peer
        if peer == "two":
            assert self.headers.get("Authorization") == "Bearer target-token"
        if peer == "one":
            assert self.headers.get("Authorization") == "Bearer source-token"
        REQUESTS.append({"peer": peer, "method": method, "body": body})
        def reply(value):
            if version == "0.3":
                validate(value, "Message" if value.get("kind") == "message" else "Task")
            self.json_reply({"jsonrpc": "2.0", "id": body["id"], "result": value})
        if method in ("SendMessage", "SendStreamingMessage", "message/send", "message/stream"):
            msg = params["message"]
            assert msg["messageId"] and msg["role"] == ("user" if version == "0.3" else "ROLE_USER")
            if version == "0.3":
                assert msg["kind"] == "message" and msg["parts"][0]["kind"] == "text"
                assert params["configuration"]["blocking"] is False
            else:
                assert params["configuration"]["returnImmediately"] is True
                assert "kind" not in msg and "kind" not in msg["parts"][0]
            text = msg["parts"][0]["text"]
            if text == "slow":
                time.sleep(0.2)
            if text == "bad-id":
                self.json_reply({"jsonrpc": "2.0", "id": "different", "result": {}})
                return
            if text == "direct":
                value = message("Direct hello 🐯", version)
                reply(value if version == "0.3" else {"message": value})
                return
            identifier = msg.get("taskId", str(uuid.uuid4()))
            value = task(identifier, "INPUT_REQUIRED" if text == "input" else "WORKING", version)
            TASKS[identifier] = {"value": value, "version": version, "hold": text == "hold"}
            if "Streaming" in method or method == "message/stream":
                first = value if version == "0.3" else {"task": value}
                results = [first]
                if text not in ("disconnect", "hold", "input"):
                    for text_part, append in [("Hel", False), ("lo 🐯", True)]:
                        art = {"artifactId": "artifact-1", "parts": [{"text": text_part}]}
                        delta = {"taskId": identifier, "contextId": value["contextId"],
                                 "artifact": art, "append": append, "lastChunk": append}
                        if version == "0.3":
                            art["parts"][0]["kind"] = "text"
                            delta["kind"] = "artifact-update"
                            results.append(delta)
                        else:
                            results.append({"artifactUpdate": delta})
                    value["status"]["state"] = "completed" if version == "0.3" else "TASK_STATE_COMPLETED"
                    delta = {"taskId": identifier, "contextId": value["contextId"], "status": value["status"]}
                    if version == "0.3":
                        delta.update(kind="status-update", final=True)
                        results.append(delta)
                    else:
                        results.append({"statusUpdate": delta})
                    # Keep the first streamed snapshot nonterminal.
                    results[0] = task(identifier, version=version) if version == "0.3" else {
                        "task": task(identifier, version=version)}
                frames = [{"jsonrpc": "2.0", "id": body["id"], "result": result} for result in results]
                if version == "0.3":
                    for frame in frames:
                        validate(frame, "SendStreamingMessageResponse")
                self.sse(frames, truncated=text == "truncated")
            else:
                reply(value if version == "0.3" else {"task": value})
        elif method in ("GetTask", "tasks/get", "CancelTask", "tasks/cancel"):
            item = TASKS[params["id"]]
            value = item["value"]
            if method in ("CancelTask", "tasks/cancel"):
                value["status"]["state"] = "canceled" if version == "0.3" else "TASK_STATE_CANCELED"
            elif not item["hold"] and value["status"]["state"] not in ("input-required", "TASK_STATE_INPUT_REQUIRED"):
                value["status"]["state"] = "completed" if version == "0.3" else "TASK_STATE_COMPLETED"
                value["history"] = [message("Polled result", version, value["contextId"])]
            reply(value)
        elif method == "ListTasks":
            reply({"tasks": [], "nextPageToken": "", "pageSize": 50, "totalSize": 0})
        elif method in ("SubscribeToTask", "tasks/resubscribe"):
            value = TASKS[params["id"]]["value"]
            result = value if version == "0.3" else {"task": value}
            self.sse([{"jsonrpc": "2.0", "id": body["id"], "result": result}])
        else:
            self.json_reply({"jsonrpc": "2.0", "id": body["id"],
                             "error": {"code": -32601, "message": "Unknown fixture method"}})


def main():
    global BASE
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    BASE = f"http://127.0.0.1:{server.server_port}"
    threading.Thread(target=server.serve_forever, daemon=True).start()
    root = pathlib.Path(__file__).resolve().parents[1]
    nvim = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else "nvim"
    with tempfile.TemporaryDirectory(prefix="diver-agent-tests-") as directory:
        env = dict(os.environ, ACP_TEST_BASE=BASE, ACP_TEST_ROOT=str(root), ACP_TEST_TMP=directory,
                   SOURCE_TOKEN="source-token", TARGET_TOKEN="target-token")
        result = subprocess.run([str(nvim), "--headless", "-u", "NONE", "-l", str(root / "tests/run.lua")],
                                env=env, timeout=45, check=False)
    server.shutdown()
    delegated = [r for r in REQUESTS if r.get("peer") == "two" and r["method"] in ("SendMessage", "SendStreamingMessage")]
    assert len(delegated) == 1, f"expected one approved delegation, got {len(delegated)}"
    assert "contextId" not in delegated[0]["body"]["params"]["message"]
    assert "taskId" not in delegated[0]["body"]["params"]["message"]
    assert not FAILURES, FAILURES
    print(f"HTTP fixture: {len(REQUESTS)} requests verified; isolated credentials and fresh delegation IDs verified; {SCHEMA_CHECKS} upstream schema checks")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
