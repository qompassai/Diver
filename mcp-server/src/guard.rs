//! Era guard: the byte-level front door of the server.
//!
//! rmcp's service layer enforces the modern era at the message
//! level (discover negotiation, per-request `_meta` validation)
//! once the handler pins `supported_protocol_versions` to
//! 2026-07-28 — but it silently drops lines it cannot parse, and it
//! will still *answer* an `initialize` request (with the
//! unsupported-version refusal) only by failing the whole serve.
//! This guard sits in front of the SDK on stdio and owns the
//! framing contract, following the fleet guard pattern (periscope /
//! phlow) with the shapes adapted to this server's measured Lua
//! baseline (`lua/ai/mcp/server/protocol.lua` + `stdio.lua`):
//!
//! - malformed JSON → `-32700 "Parse error"` (the baseline's exact
//!   fixed string), id null; oversized line → `-32700 "message
//!   exceeds size limit"` with the rest drained and the server
//!   alive (the fleet shape; the baseline dropped oversized lines
//!   silently — itemized in the WS3 gate report)
//! - non-object frames → `-32600 "request must be a JSON object"`
//!   (the fleet shape; the baseline dropped scalars silently and
//!   answered batches with its own text — itemized); an id that is
//!   not a string or number → the baseline's `-32600 "request id
//!   must be a string or number"`, id null; a frame whose method is
//!   missing/not a string or whose jsonrpc is not "2.0" → the
//!   baseline's `-32600 "invalid request"`
//! - `initialize` (any version) → the designed modern-only refusal,
//!   `-32022` naming the supported versions; the connection and the
//!   process stay up, so a probe can continue with modern frames
//! - unknown methods → `-32601 "method not found: {method}"` (the
//!   baseline's exact message); notifications (no `id`) are dropped
//!   silently — the baseline's notification handlers had no
//!   wire-visible effect, and the modern era has no `initialized`
//!   gate to reproduce
//! - only `server/discover`, `tools/list`, and `tools/call` frames
//!   are forwarded; `ping` is answered here with the baseline's
//!   empty result (the SDK -32601s a ping after the first real
//!   request; the baseline answered it at any point in a session).
//!   Forwarded frames pass through except for
//!   the normalizations that reproduce the baseline's handler-level
//!   contract inside the SDK's typed envelope: a missing `params`
//!   becomes `{}` (a non-object `params` is the baseline's `-32602
//!   "params must be an object"`, answered here); on tools/call, a
//!   missing or non-string/empty `name` earns the baseline's
//!   `-32602 "name must be a non-empty string"`, an empty-array
//!   `arguments` becomes `{}` (a JSON array decodes to the empty
//!   table in the Lua server — the F-1 shape), a non-empty array
//!   earns `-32602 "unknown argument: 1"` (what the baseline's
//!   validator says about its first key), any other non-object
//!   `arguments` earns `-32602 "arguments must be an object"`, and a
//!   non-object `_meta` earns `-32602 "_meta must be an object"`;
//!   on tools/list, a non-string `cursor` earns `-32602 "cursor
//!   must be a string"`.

use std::sync::Arc;

use serde_json::{Map, Value, json};
use tokio::io::{
    AsyncBufRead, AsyncBufReadExt, AsyncWriteExt, BufReader, DuplexStream, ReadHalf, Stdin, Stdout,
    WriteHalf,
};
use tokio::sync::Mutex;

/// The one protocol version this server speaks.
pub const MODERN_VERSION: &str = "2026-07-28";
/// Maximum bytes in one JSON-RPC line (the baseline's cap, shared
/// with the diver client).
const MAX_LINE_BYTES: usize = 8 * 1024 * 1024;

const INVALID_PARAMS: i32 = -32602;
const INVALID_REQUEST: i32 = -32600;
const METHOD_NOT_FOUND: i32 = -32601;
const PARSE_ERROR: i32 = -32700;
const UNSUPPORTED_PROTOCOL_VERSION: i32 = -32022;

/// Stdout shared by the guard (its own error frames) and the pump
/// (SDK responses); one line is written per lock, never interleaved.
pub type SharedStdout = Arc<Mutex<Stdout>>;

/// Response-ordering state shared by the guard and the pump: the
/// ids of forwarded requests whose SDK response has not yet been
/// written to stdout. The baseline answered strictly in request
/// order; the guard therefore never writes one of its own frames
/// while an earlier forwarded request is unanswered (without this,
/// a guard frame — answered instantly — overtakes the SDK's first
/// response, which pays the service bootstrap latency).
pub struct Ordering {
    outstanding: Mutex<Vec<Value>>,
    drained: tokio::sync::Notify,
}

impl Ordering {
    pub fn new() -> Arc<Self> {
        Arc::new(Ordering {
            outstanding: Mutex::new(Vec::new()),
            drained: tokio::sync::Notify::new(),
        })
    }

    async fn track(&self, id: Value) {
        self.outstanding.lock().await.push(id);
    }

    async fn complete(&self, id: &Value) {
        {
            let mut queue = self.outstanding.lock().await;
            if let Some(pos) = queue.iter().position(|q| q == id) {
                queue.remove(pos);
            }
        }
        self.drained.notify_waiters();
    }

    /// Wait until no forwarded request is unanswered. Bounded: if
    /// the SDK died mid-request its response will never come, and
    /// the guard must go on answering framing errors regardless.
    async fn wait_drained(&self) {
        let deadline = std::time::Duration::from_secs(5);
        let _ = tokio::time::timeout(deadline, async {
            loop {
                let notified = self.drained.notified();
                if self.outstanding.lock().await.is_empty() {
                    return;
                }
                notified.await;
            }
        })
        .await;
    }
}

fn error_frame(id: Value, code: i32, message: &str) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
}

fn result_frame(id: Value, result: Value) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "result": result})
}

/// The designed refusal of legacy-era contact (CHECKLIST 1.8 shape:
/// the SDK's own `unsupported_protocol_version` payload).
fn unsupported_version_frame(id: Value, requested: Value) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": {
            "code": UNSUPPORTED_PROTOCOL_VERSION,
            "message": "Unsupported protocol version",
            "data": {"requested": requested, "supported": [MODERN_VERSION]}
        }
    })
}

/// What the guard does with one inbound line.
#[derive(Debug, PartialEq)]
enum Action {
    /// Forward this (possibly shape-normalized) frame to the SDK.
    Forward(Value),
    /// Answer it here; the SDK never sees it.
    Respond(Value),
    /// Drop silently (blank line, notification).
    Drop,
}

/// Classify one line. Pure: unit-tested without any transport.
fn classify(line: &[u8]) -> Action {
    let text = String::from_utf8_lossy(line);
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Action::Drop;
    }
    let value: Value = match serde_json::from_str(trimmed) {
        Ok(v) => v,
        Err(_) => {
            return Action::Respond(error_frame(Value::Null, PARSE_ERROR, "Parse error"));
        }
    };
    let Some(object) = value.as_object() else {
        return Action::Respond(error_frame(
            Value::Null,
            INVALID_REQUEST,
            "request must be a JSON object",
        ));
    };
    // No `id` key: a notification. Dropped silently (see the module
    // docs); a notification-shaped initialize drops the same way.
    if !object.contains_key("id") {
        return Action::Drop;
    }
    let id = object.get("id").cloned().unwrap_or(Value::Null);
    if !id.is_string() && !id.is_number() {
        return Action::Respond(error_frame(
            Value::Null,
            INVALID_REQUEST,
            "request id must be a string or number",
        ));
    }
    let method = object.get("method").and_then(Value::as_str);
    if object.get("jsonrpc").and_then(Value::as_str) != Some("2.0") || method.is_none() {
        return Action::Respond(error_frame(id, INVALID_REQUEST, "invalid request"));
    }
    let method = method.expect("checked above");
    match method {
        "initialize" => {
            let requested = object
                .get("params")
                .and_then(|p| p.get("protocolVersion"))
                .and_then(Value::as_str)
                .map_or(Value::Null, |v| Value::String(v.to_string()));
            Action::Respond(unsupported_version_frame(id, requested))
        }
        "server/discover" => match normalize_params(value) {
            Ok(frame) => Action::Forward(frame),
            Err(frame) => Action::Respond(frame),
        },
        // The baseline answered ping itself, statelessly, with an
        // empty result. The SDK answers it only before the first
        // real request and -32601s it afterwards (measured against
        // rmcp 3.8.0), so the guard keeps the baseline's behavior.
        "ping" => match normalize_params(value) {
            Ok(_) => Action::Respond(result_frame(id, json!({}))),
            Err(frame) => Action::Respond(frame),
        },
        "tools/list" => classify_list(value, id),
        "tools/call" => classify_call(value, id),
        _ => Action::Respond(error_frame(
            id,
            METHOD_NOT_FOUND,
            &format!("method not found: {method}"),
        )),
    }
}

/// Ensure `params` exists as an object: a missing value becomes {}
/// (the baseline's handlers default it), a non-object value is the
/// baseline's -32602, answered here.
fn normalize_params(mut value: Value) -> Result<Value, Value> {
    let id = value.get("id").cloned().unwrap_or(Value::Null);
    let object = value.as_object_mut().expect("classified object");
    match object.get("params") {
        Some(p) if p.is_object() => {}
        Some(_) => {
            return Err(error_frame(id, INVALID_PARAMS, "params must be an object"));
        }
        None => {
            object.insert("params".to_string(), json!({}));
        }
    }
    Ok(value)
}

fn params_map(value: &mut Value) -> &mut Map<String, Value> {
    value
        .as_object_mut()
        .expect("classified object")
        .get_mut("params")
        .and_then(Value::as_object_mut)
        .expect("params normalized to an object")
}

fn classify_list(value: Value, id: Value) -> Action {
    let mut value = match normalize_params(value) {
        Ok(frame) => frame,
        Err(frame) => return Action::Respond(frame),
    };
    let params = params_map(&mut value);
    if let Some(cursor) = params.get("cursor")
        && !cursor.is_string()
    {
        return Action::Respond(error_frame(id, INVALID_PARAMS, "cursor must be a string"));
    }
    Action::Forward(value)
}

/// Classify a `tools/call` frame: the baseline's shape errors are
/// answered here with its exact codes and messages (the SDK's typed
/// request cannot represent them); a well-formed call forwards.
fn classify_call(value: Value, id: Value) -> Action {
    let mut value = match normalize_params(value) {
        Ok(frame) => frame,
        Err(frame) => return Action::Respond(frame),
    };
    let params = params_map(&mut value);
    if let Some(meta) = params.get("_meta")
        && !meta.is_object()
    {
        return Action::Respond(error_frame(id, INVALID_PARAMS, "_meta must be an object"));
    }
    let name_ok = params
        .get("name")
        .and_then(Value::as_str)
        .is_some_and(|name| !name.is_empty());
    if !name_ok {
        return Action::Respond(error_frame(
            id,
            INVALID_PARAMS,
            "name must be a non-empty string",
        ));
    }
    match params.get("arguments") {
        None => {
            params.insert("arguments".to_string(), json!({}));
        }
        Some(arguments) if arguments.is_object() => {}
        Some(arguments) => match arguments.as_array() {
            Some(array) if array.is_empty() => {
                params.insert("arguments".to_string(), json!({}));
            }
            Some(_) => {
                return Action::Respond(error_frame(id, INVALID_PARAMS, "unknown argument: 1"));
            }
            None => {
                return Action::Respond(error_frame(
                    id,
                    INVALID_PARAMS,
                    "arguments must be an object",
                ));
            }
        },
    }
    Action::Forward(value)
}

async fn write_frame(stdout: &SharedStdout, frame: &Value) {
    let mut line = serde_json::to_string(frame).unwrap_or_default();
    line.push('\n');
    let mut out = stdout.lock().await;
    let _ = out.write_all(line.as_bytes()).await;
    let _ = out.flush().await;
}

async fn write_bytes(stdout: &SharedStdout, bytes: &[u8]) {
    let mut out = stdout.lock().await;
    let _ = out.write_all(bytes).await;
    let _ = out.flush().await;
}

/// One inbound line, bounded: the error trips when the content
/// (excluding the newline) reaches [`MAX_LINE_BYTES`]; an oversized
/// line's remainder is drained.
enum LineOutcome {
    Line(Vec<u8>),
    Oversized,
    Eof,
}

async fn next_line<R: AsyncBufRead + Unpin>(reader: &mut R) -> std::io::Result<LineOutcome> {
    let mut out: Vec<u8> = Vec::new();
    let mut content_len = 0usize;
    let mut oversized = false;
    loop {
        let chunk = reader.fill_buf().await?;
        if chunk.is_empty() {
            return Ok(if oversized {
                LineOutcome::Oversized
            } else if out.is_empty() && content_len == 0 {
                LineOutcome::Eof
            } else {
                LineOutcome::Line(out)
            });
        }
        match chunk.iter().position(|&b| b == b'\n') {
            Some(pos) => {
                content_len += pos;
                if content_len >= MAX_LINE_BYTES {
                    oversized = true;
                }
                if !oversized {
                    out.extend_from_slice(&chunk[..pos]);
                }
                reader.consume(pos + 1);
                return Ok(if oversized {
                    LineOutcome::Oversized
                } else {
                    LineOutcome::Line(out)
                });
            }
            None => {
                let len = chunk.len();
                content_len += len;
                if content_len >= MAX_LINE_BYTES {
                    oversized = true;
                    out.clear();
                } else {
                    out.extend_from_slice(chunk);
                }
                reader.consume(len);
            }
        }
    }
}

/// Run the guard until stdin reaches EOF, then shut the duplex
/// write side down: a split write half signals end-of-input to the
/// SDK service only through an explicit shutdown, never by being
/// dropped (both halves share ownership of the stream).
pub async fn run(
    stdin: Stdin,
    mut to_server: WriteHalf<DuplexStream>,
    stdout: SharedStdout,
    ordering: Arc<Ordering>,
) -> std::io::Result<()> {
    let result = forward_loop(stdin, &mut to_server, &stdout, &ordering).await;
    let _ = to_server.shutdown().await;
    result
}

async fn forward_loop(
    stdin: Stdin,
    to_server: &mut WriteHalf<DuplexStream>,
    stdout: &SharedStdout,
    ordering: &Ordering,
) -> std::io::Result<()> {
    let mut reader = BufReader::new(stdin);
    loop {
        match next_line(&mut reader).await? {
            LineOutcome::Eof => return Ok(()),
            LineOutcome::Oversized => {
                ordering.wait_drained().await;
                write_frame(
                    stdout,
                    &error_frame(Value::Null, PARSE_ERROR, "message exceeds size limit"),
                )
                .await;
            }
            LineOutcome::Line(bytes) => match classify(&bytes) {
                Action::Drop => {}
                Action::Respond(frame) => {
                    ordering.wait_drained().await;
                    write_frame(stdout, &frame).await;
                }
                Action::Forward(frame) => {
                    if let Some(id) = frame.get("id").cloned() {
                        ordering.track(id).await;
                    }
                    let mut line = serde_json::to_string(&frame).unwrap_or_default();
                    line.push('\n');
                    to_server.write_all(line.as_bytes()).await?;
                    to_server.flush().await?;
                }
            },
        }
    }
}

/// Copy SDK responses from the duplex to stdout, one line at a time,
/// marking each answered request id complete for the guard's
/// ordering wait.
pub async fn pump(
    mut from_server: ReadHalf<DuplexStream>,
    stdout: SharedStdout,
    ordering: Arc<Ordering>,
) {
    let mut reader = BufReader::new(&mut from_server);
    let mut line: Vec<u8> = Vec::new();
    loop {
        line.clear();
        match reader.read_until(b'\n', &mut line).await {
            Ok(0) | Err(_) => return,
            Ok(_) => {
                write_bytes(&stdout, &line).await;
                if let Ok(frame) = serde_json::from_slice::<Value>(&line)
                    && let Some(id) = frame.get("id")
                {
                    ordering.complete(id).await;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn classify_str(s: &str) -> Action {
        classify(s.as_bytes())
    }

    fn classify_json(frame: &Value) -> Action {
        classify(serde_json::to_string(frame).unwrap().as_bytes())
    }

    fn modern_meta() -> Value {
        json!({
            "io.modelcontextprotocol/protocolVersion": "2026-07-28",
            "io.modelcontextprotocol/clientInfo": {"name": "test", "version": "1"},
            "io.modelcontextprotocol/clientCapabilities": {},
        })
    }

    fn modern_call(id: u64, params: Value) -> Value {
        let mut params = params;
        params
            .as_object_mut()
            .expect("object params")
            .insert("_meta".to_string(), modern_meta());
        json!({"jsonrpc": "2.0", "id": id, "method": "tools/call", "params": params})
    }

    #[test]
    fn blank_lines_and_notifications_drop() {
        assert_eq!(classify_str("  \n"), Action::Drop);
        assert_eq!(
            classify_str("{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"),
            Action::Drop
        );
        assert_eq!(
            classify_str("{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{}}"),
            Action::Drop
        );
    }

    #[test]
    fn framing_errors_match_the_baseline() {
        match classify_str("this is not json") {
            Action::Respond(f) => {
                assert_eq!(f["error"]["code"], PARSE_ERROR);
                assert_eq!(f["error"]["message"], "Parse error");
                assert_eq!(f["id"], Value::Null);
            }
            other => panic!("expected respond, got {other:?}"),
        }
        match classify_str("42") {
            Action::Respond(f) => {
                assert_eq!(f["error"]["code"], INVALID_REQUEST);
                assert_eq!(f["error"]["message"], "request must be a JSON object");
            }
            other => panic!("expected respond, got {other:?}"),
        }
        match classify_str("{\"jsonrpc\":\"2.0\",\"id\":true,\"method\":\"ping\"}") {
            Action::Respond(f) => {
                assert_eq!(
                    f["error"]["message"],
                    "request id must be a string or number"
                );
                assert_eq!(f["id"], Value::Null);
            }
            other => panic!("expected respond, got {other:?}"),
        }
        // A response-shaped frame (id, no method) takes the
        // baseline's invalid-request answer.
        match classify_str("{\"jsonrpc\":\"2.0\",\"id\":9,\"result\":{}}") {
            Action::Respond(f) => assert_eq!(f["error"]["message"], "invalid request"),
            other => panic!("expected respond, got {other:?}"),
        }
    }

    #[test]
    fn initialize_is_refused_with_supported_versions() {
        let frame = "{\"id\":7,\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"clientInfo\":{\"name\":\"x\"}}}";
        match classify_str(frame) {
            Action::Respond(f) => {
                assert_eq!(f["id"], 7);
                assert_eq!(f["error"]["code"], UNSUPPORTED_PROTOCOL_VERSION);
                assert_eq!(f["error"]["data"]["requested"], "2025-11-25");
                assert_eq!(f["error"]["data"]["supported"], json!(["2026-07-28"]));
            }
            other => panic!("expected respond, got {other:?}"),
        }
    }

    #[test]
    fn unknown_methods_carry_the_method_name() {
        let frame = "{\"id\":1,\"jsonrpc\":\"2.0\",\"method\":\"resources/list\",\"params\":{}}";
        match classify_str(frame) {
            Action::Respond(f) => {
                assert_eq!(f["error"]["code"], METHOD_NOT_FOUND);
                assert_eq!(f["error"]["message"], "method not found: resources/list");
            }
            other => panic!("expected respond, got {other:?}"),
        }
    }

    #[test]
    fn call_shape_errors_match_the_baseline() {
        for (frame, message) in [
            (
                modern_call(1, json!({"arguments": {}})),
                "name must be a non-empty string",
            ),
            (
                modern_call(2, json!({"name": "", "arguments": {}})),
                "name must be a non-empty string",
            ),
            (
                modern_call(3, json!({"name": "read_file", "arguments": "nope"})),
                "arguments must be an object",
            ),
            (
                modern_call(4, json!({"name": "read_file", "arguments": [1]})),
                "unknown argument: 1",
            ),
        ] {
            match classify_json(&frame) {
                Action::Respond(f) => {
                    assert_eq!(f["error"]["code"], INVALID_PARAMS);
                    assert_eq!(f["error"]["message"], message);
                }
                other => panic!("expected respond for {frame}, got {other:?}"),
            }
        }
        // The F-1 shape: empty-array arguments normalize to {}.
        match classify_json(&modern_call(
            5,
            json!({"name": "list_files", "arguments": []}),
        )) {
            Action::Forward(f) => assert_eq!(f["params"]["arguments"], json!({})),
            other => panic!("expected forward, got {other:?}"),
        }
        // Missing params entirely become {} before forwarding.
        match classify_str("{\"id\":6,\"jsonrpc\":\"2.0\",\"method\":\"tools/list\"}") {
            Action::Forward(f) => assert_eq!(f["params"], json!({})),
            other => panic!("expected forward, got {other:?}"),
        }
        // Non-object params are the baseline's -32602.
        match classify_str(
            "{\"id\":7,\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"params\":\"x\"}",
        ) {
            Action::Respond(f) => assert_eq!(f["error"]["message"], "params must be an object"),
            other => panic!("expected respond, got {other:?}"),
        }
    }

    #[test]
    fn valid_modern_frames_forward() {
        for frame in [
            json!({"id": 1, "jsonrpc": "2.0", "method": "server/discover", "params": {"_meta": modern_meta()}}),
            json!({"id": 2, "jsonrpc": "2.0", "method": "tools/list", "params": {"_meta": modern_meta()}}),
            modern_call(3, json!({"name": "read_file", "arguments": {"path": "x"}})),
        ] {
            match classify_json(&frame) {
                Action::Forward(_) => {}
                other => panic!("expected forward for {frame}, got {other:?}"),
            }
        }
        // Ping is answered here with the baseline's empty result.
        match classify_json(&json!({"id": 4, "jsonrpc": "2.0", "method": "ping"})) {
            Action::Respond(f) => assert_eq!(f["result"], json!({})),
            other => panic!("expected respond for ping, got {other:?}"),
        }
    }
}
